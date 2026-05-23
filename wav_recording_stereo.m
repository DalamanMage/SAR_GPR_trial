clc; clearvars; close all

deviceID   = 1;               
Fs         = 192000;
nBits      = 24;
nChannels  = 2;
recTime    = 20;
filename   = 'mit_style_capture_stereo.wav';

recObj = audiorecorder(Fs, nBits, nChannels, deviceID);

for k = 3:-1:1
    fprintf('Kayit %d...\n', k);
    pause(1);
end

disp('REC')
recordblocking(recObj, recTime);
disp('STOP')

y = getaudiodata(recObj, 'double');
audiowrite(filename, y, Fs);

fprintf('Kaydedildi: %s\n', filename);
fprintf('Ornekleme: %d Hz\n', Fs);
fprintf('Kanal sayisi: %d\n', size(y,2));
fprintf('Toplam sure: %.3f s\n', size(y,1)/Fs);

t = (0:size(y,1)-1)/Fs;

figure;
subplot(2,1,1)
plot(t, y(:,1))
grid on
xlabel('Time (s)')
ylabel('Amplitude')
title('Channel 1')

subplot(2,1,2)
plot(t, y(:,2))
grid on
xlabel('Time (s)')
ylabel('Amplitude')
title('Channel 2')