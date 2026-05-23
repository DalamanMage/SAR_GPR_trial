clc; clear; close all;


%% Audio cihazlarini yenile ve listele
audiodevreset;
info = audiodevinfo;

disp("INPUT DEVICES:");
for k = 1:numel(info.input)
    
    fprintf("%d : %s\n", info.input(k).ID, info.input(k).Name);
end

%% 2) Buraya test etmek istedigin device ID'yi gir
deviceID = 0;   % <- bunu Focusrite'in dogru ID'si ile degistir
Fs       = 192000;

fprintf('\n=== CHANNEL SUPPORT TEST FOR DEVICE ID %d ===\n', deviceID);

%% 3) Kac kanal destekliyor test et
for ch = 1:4
    try
        recObj = audiorecorder(Fs, 16, ch, deviceID); %#ok<NASGU>
        fprintf('OK   : %d channel(s) supported at %d Hz\n', ch, Fs);
    catch ME
        fprintf('FAIL : %d channel(s) NOT supported at %d Hz --> %s\n', ch, Fs, ME.message);
    end
end

%% 4) 2 kanal test kaydi al
fprintf('\n=== TRYING 2-CHANNEL RECORDING ===\n');

try
    recTime = 3;          % 3 saniye
    nBits   = 16;
    nCh     = 2;

    recObj = audiorecorder(Fs, nBits, nCh, deviceID);

    disp('3 saniyelik stereo test kaydi basliyor...');
    recordblocking(recObj, recTime);
    disp('Kayit bitti.');

    y = getaudiodata(recObj, 'double');

    fprintf('Kayittan donen kanal sayisi: %d\n', size(y,2));
    fprintf('Ornek sayisi: %d\n', size(y,1));
    fprintf('Sure: %.3f s\n', size(y,1)/Fs);

    if size(y,2) == 2
        disp('SONUC: Cihaz MATLAB tarafinda 2 kanalli okunabiliyor.');
    elseif size(y,2) == 1
        disp('SONUC: Kayit mono geldi. MATLAB veya secilen endpoint tek kanal aciyor.');
    else
        disp('SONUC: Beklenmeyen kanal sayisi dondu.');
    end

    t = (0:size(y,1)-1)/Fs;

    figure;
    if size(y,2) >= 2
        subplot(2,1,1);
        plot(t, y(:,1));
        grid on;
        xlabel('Time (s)');
        ylabel('Amp');
        title('Channel 1');

        subplot(2,1,2);
        plot(t, y(:,2));
        grid on;
        xlabel('Time (s)');
        ylabel('Amp');
        title('Channel 2');
    else
        plot(t, y(:,1));
        grid on;
        xlabel('Time (s)');
        ylabel('Amp');
        title('Mono Recording');
    end

catch ME
    fprintf('2-kanal test kaydi basarisiz: %s\n', ME.message);
end