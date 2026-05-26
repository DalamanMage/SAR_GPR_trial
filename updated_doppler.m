
% File name
filename = 'mit_style_capture.wav';

% Read WAV (modern MATLAB)
info = audioinfo(filename);
[Y,FS] = audioread(filename);
NBITS = info.BitsPerSample; %#ok<NASGU>

% constants
c = 3E8; %(m/s)

% radar parameters
Tp = 0.250;                 %(s) pulse time
N = round(Tp * FS);         %# of samples per pulse

% Set this to your actual CW carrier frequency
fc = 2250E6;                %(Hz)
% fc = 2590E6;              %(Hz) if that matches your fixed VCO setting

% mono / stereo handling
if size(Y,2) == 1
    s = -1 * Y(:,1);
else
    % if stereo, still use channel 2 like the MIT script
    s = -1 * Y(:,2);
end

clear Y;

% create Doppler vs. time data set
numBlocks = floor(length(s) / N);
sif = zeros(numBlocks, N);

for ii = 1:numBlocks
    idx1 = 1 + (ii-1)*N;
    idx2 = ii*N;
    sif(ii,:) = s(idx1:idx2);
end

% subtract average DC term
sif = sif - mean(s);

zpad = 4 * N;   % same as original 8*N/2

% Doppler vs. time plot
v = dbv(ifft(sif, zpad, 2));
v = v(:, 1:size(v,2)/2);
mmax = max(v(:));

% calculate velocity
delta_f = linspace(0, FS/2, size(v,2)); %(Hz)
lambda = c / fc;
velocity = delta_f * lambda / 2;

% calculate time
time = linspace(1, Tp * size(v,1), size(v,1)); %(sec)

% plot
imagesc(velocity, time, v - mmax, [-35, 0]);
axis xy;
colorbar;
xlim([0 40]);
xlabel('Velocity (m/sec)');
ylabel('Time (sec)');
title('Doppler vs. Time Intensity');