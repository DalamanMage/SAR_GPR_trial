% read_data_range_mit_like.m
% MIT'e yakin range / RTI isleme surumu
% Pratik degisiklikler:
% 1) wavread -> audioread
% 2) trigger tespitinde abs() kullanimi (senin sync kaydina daha uygun)

clear all;
close all;
clc;

%% ================= USER SETTINGS =================
filename = 'mit_style_capture_stereo.wav';

% Kanal atamasi (MIT mantigi)
CH_TRIG = 2;   % sync / trigger
CH_IF   = 1;   % IF / dechirped signal

% Gerekirse tersle
invertTrig = true;
invertIF   = true;

% Senin sync icin bu gerekliydi
useAbsTrigger = true;

% MIT'e yakin threshold ve zaman ayarlari
thresh = 0.02;       % gerekirse 0.02-0.08 arasi oyna
Tp     = 20E-3;      % pulse time
Trp    = 0.25;       % min range profile time duration

% RF sweep
fstart = 2.160E9;
fstop  = 2.360E9;

% Plot
Nfft = 4096;
dynamicRangeDB = 40;
rangeMaxToShow = 5;

% Sabit hedef icin false birak
use2PulseCanceller = false;
%% ================================================

%% Read WAV
info = audioinfo(filename);
[Y,FS] = audioread(filename);
NBITS = info.BitsPerSample; %#ok<NASGU>

fprintf('Fs = %d Hz, channels = %d, duration = %.3f s\n', FS, size(Y,2), size(Y,1)/FS);

if size(Y,2) < 2
    error('Bu script stereo WAV bekliyor: Ch1=sync, Ch2=IF');
end

%% Constants
c = 3E8; % speed of light

%% Radar parameters
N = round(Tp * FS);          % samples per pulse
Nrp = round(Trp * FS);       % min # samples between range profiles
BW = fstop - fstart;         % transmit bandwidth
S  = BW / Tp;                % chirp slope

fprintf('BW = %.3f MHz\n', BW/1e6);
fprintf('Range resolution ~= %.3f m\n', c/(2*BW));

%% Input channels
trig = Y(:, CH_TRIG);
s    = Y(:, CH_IF);

if invertTrig
    trig = -1 * trig;
end
if invertIF
    s = -1 * s;
end

clear Y;

%% Parse pulses by direct rising-edge detection
if useAbsTrigger
    trig_metric = abs(trig);
else
    trig_metric = trig;
end

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

% debounce / false edge suppression
minSpacingSec = 0.030;           % 40 ms period icin guvenli
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

% only keep edges with enough IF data after them
edgeIdx = edgeIdx(edgeIdx + N - 1 <= length(s));

if isempty(edgeIdx)
    error('Edge bulundu ama 20 ms IF penceresi cikartilamadi.');
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

%% Remove DC from each pulse
for ii = 1:size(profiles,1)
    profiles(ii,:) = profiles(ii,:) - mean(profiles(ii,:));
end

%% Apply Hann window
w = hann(N).';
profiles_win = profiles .* w;

%% Optional 2-pulse canceller
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

%% Range FFT
R = fft(proc, Nfft, 2);
R = R(:, 1:Nfft/2);

magDB = 20*log10(abs(R) + 1e-12);
magDB = magDB - max(magDB(:));

%% Range axis
fb = (0:(Nfft/2 - 1)) * (FS / Nfft);
range_m = c * fb / (2 * S);

%% RTI
figure;
imagesc(range_m, timeAxis, magDB, [-dynamicRangeDB 0]);
axis xy;
xlabel('Range (m)');
ylabel('Time (s)');
title('Range-Time Intensity (RTI)');
colorbar;
xlim([0 rangeMaxToShow]);

%% Average range profile
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
hold on;
xline(1.2, '--r', '1.2 m');

%% Debug plots
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
title('Trigger / Sync');

subplot(3,1,3);
plot((0:N-1)/FS*1e3, profiles(1,:));
grid on;
xlabel('Fast time (ms)');
ylabel('Amplitude');
title('First extracted 20 ms profile');