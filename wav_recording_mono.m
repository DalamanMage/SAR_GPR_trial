clc, clearvars, close all

deviceID   = 1;               
Fs         = 192000;
nBits      = 24;
nChannels  = 1;
recTime    = 15;
filename   = 'mit_style_capture.wav';

recObj = audiorecorder(Fs, nBits, nChannels, deviceID);

for k = 3:-1:1
    fprintf('Kayit %d...\n', k);
    pause(1);
end

disp('REC')
recordblocking(recObj, recTime);
disp('STOP')

y1 = getaudiodata(recObj, 'double');
audiowrite(filename, y1, Fs);

fprintf('Kaydedildi: %s\n', filename);
fprintf('Ornekleme: %d Hz\n', Fs);
fprintf('Kanal sayisi: %d\n', size(y1,2));
fprintf('Toplam sure: %.3f s\n', size(y1,1)/Fs);

t = (0:size(y1,1)-1)/Fs;
figure;
plot(t,y1)
grid on
xlabel('Time (s)')
ylabel('Amplitude')
title('Recorded Signal')

if size(y1,2) == 1
    legend('Channel 1')
else
    legend('Left / Ch1','Right / Ch2')
end