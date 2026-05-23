% read_data_RTI_moving_target.m
% Senaryo:
% - radar sabit
% - hedef (sen) hareketli
% - stereo WAV: Ch2 = sync, Ch1 = IF
% - sync edge'inden itibaren 20 ms IF penceresi alinip RTI uretilir

clear; close all; clc;

%% ================= USER SETTINGS =================
filename = 'mit_style_capture_stereo.wav';

% Kanal atamasi
CH_TRIG = 2;   % sync / trigger
CH_IF   = 1;   % IF / dechirped signal

% Gerekirse tersle
invertTrig = true;
invertIF   = true;

% Sync detection
useAbsTrigger = true;   % ses karti AC-coupled ise genelde daha iyi
thresh = 0.02;          % 0.01 - 0.05 arasi denenebilir
minSpacingSec = 0.030;  % 40 ms period icin sahte edge eleme

% Chirp timing
Tp = 20e-3;             % up-ramp suresi
syncOffsetSec = 0e-3;   % gerekirse 0.1e-3 gibi minik offset deneyebilirsin

% RF sweep
fstart = 2.160e9;
fstop  = 2.360e9;

% FFT / plot
Nfft = 4096;
dynamicRangeDB = 40;
rangeMaxToShow = 10;    % hareketli hedef icin 10 m ile basla

% Sabit hedefte clutter bastirma icin degil; hareketli denemede de once kapali basla
use2PulseCanceller = false;

% Window
useHannWindow = true;
%% ================================================

%% WAV oku
info = audioinfo(filename);
[Y,FS] = audioread(filename);
NBITS = info.BitsPerSample; %#ok<NASGU>

fprintf('Fs = %d Hz, channels = %d, duration = %.3f s\n', FS, size(Y,2), size(Y,1)/FS);

if size(Y,2) < 2
    error('Bu script stereo WAV bekliyor.');
end

%% Temel radar parametreleri
c = 3e8;
BW = fstop - fstart;
S  = BW / Tp;
N  = round(Tp * FS);
syncOffsetSamples = round(syncOffsetSec * FS);

fprintf('BW = %.3f MHz\n', BW/1e6);
fprintf('Range resolution ~= %.3f m\n', c/(2*BW));

%% Kanallari al
trig = Y(:, CH_TRIG);
s    = Y(:, CH_IF);

if invertTrig
    trig = -1 * trig;
end
if invertIF
    s = -1 * s;
end

clear Y;

%% ===== 1) Trigger metric =====
if useAbsTrigger
    trig_metric = abs(trig);
else
    trig_metric = trig;
end

%% ===== 2) Rising edge bul =====
start = (trig_metric > thresh);
edgeIdx = find(diff(start) == 1) + 1;

if isempty(edgeIdx)
    figure;
    plot((0:length(trig)-1)/FS, trig);
    grid on;
    xlabel('Time (s)');
    ylabel('Trigger');
    title('No trigger edge found');
    error('Hic rising edge bulunamadi. Kanal / invert / threshold ayarlarini kontrol et.');
end

%% ===== 3) Debounce / false edge suppression =====
minSpacing = round(minSpacingSec * FS);

keep = true(size(edgeIdx));
last = edgeIdx(1);

for k = 2:numel(edgeIdx)
    if edgeIdx(k) - last < minSpacing
        keep(k) = false;
    else
        last = edgeIdx(k);
    end
end

edgeIdx = edgeIdx(keep);

%% ===== 4) Gecikme offset'i uygula =====
edgeIdx = edgeIdx + syncOffsetSamples;
edgeIdx = edgeIdx(edgeIdx > 0);

%% ===== 5) 20 ms IF penceresi cikart =====
edgeIdx = edgeIdx(edgeIdx + N - 1 <= length(s));

if isempty(edgeIdx)
    error('Gecerli 20 ms pencere cikartacak edge kalmadi.');
end

profiles = zeros(numel(edgeIdx), N);
trig_profiles = zeros(numel(edgeIdx), N);

for k = 1:numel(edgeIdx)
    idx1 = edgeIdx(k);
    idx2 = idx1 + N - 1;

    profiles(k,:) = s(idx1:idx2)';
    trig_profiles(k,:) = trig(idx1:idx2)';
end

fprintf('Ayiklanan pulse sayisi: %d\n', size(profiles,1));

%% ===== 6) Her profile icin DC kaldir =====
for ii = 1:size(profiles,1)
    profiles(ii,:) = profiles(ii,:) - mean(profiles(ii,:));
end

%% ===== 7) Window uygula =====
if useHannWindow
    w = hann(N).';
else
    w = ones(1,N);
end

profiles_win = profiles .* w;

%% ===== 8) Opsiyonel 2-pulse canceller =====
if use2PulseCanceller
    if size(profiles_win,1) < 2
        error('2-pulse canceller icin en az 2 pulse gerekli.');
    end
    proc = profiles_win(2:end,:) - profiles_win(1:end-1,:);
    timeAxis = edgeIdx(2:end) / FS;
else
    proc = profiles_win;
    timeAxis = edgeIdx / FS;
end

%% ===== 9) Range FFT =====
R = fft(proc, Nfft, 2);
R = R(:, 1:Nfft/2);

magDB = 20*log10(abs(R) + 1e-12);
magDB = magDB - max(magDB(:));

%% ===== 10) Range axis =====
fb = (0:(Nfft/2 - 1)) * (FS / Nfft);
range_m = c * fb / (2 * S);

%% ===== 11) RTI =====
figure;
imagesc(range_m, timeAxis, magDB, [-dynamicRangeDB 0]);
axis xy;
xlabel('Range (m)');
ylabel('Time (s)');
title('Range-Time Intensity (RTI)');
colorbar;
xlim([0 rangeMaxToShow]);

%% ===== 12) Average range profile =====
meanProfile = mean(abs(R), 1);
meanProfileDB = 20*log10(meanProfile + 1e-12);
meanProfileDB = meanProfileDB - max(meanProfileDB);

figure;
plot(range_m, meanProfileDB, 'LineWidth', 1.5);
grid on;
xlabel('Range (m)');
ylabel('Magnitude (dB)');
title('Average Range Profile');
xlim([0 rangeMaxToShow]);
ylim([-60 5]);

%% ===== 13) Debug plots =====
figure;

subplot(3,1,1);
t = (0:length(s)-1)/FS;
plot(t, s);
grid on;
xlabel('Time (s)');
ylabel('IF');
title('IF / dechirped signal');

subplot(3,1,2);
tt = (0:length(trig)-1)/FS;
plot(tt, trig);
hold on;
plot(edgeIdx/FS, trig(edgeIdx), 'r.');
grid on;
xlabel('Time (s)');
ylabel('Trigger');
title('Trigger / Sync with detected edges');

subplot(3,1,3);
plot((0:N-1)/FS*1e3, profiles(1,:));
grid on;
xlabel('Fast time (ms)');
ylabel('Amplitude');
title('First extracted 20 ms profile');