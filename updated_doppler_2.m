%% =====================================================================
%  Doppler-Time Intensity (DTI) - YUKSEK COZUNURLUK SURUMU
%  MIT IAP Coffee-Can Radar - CW (Doppler) modu
%
%  Onceki "blok blok" gorunumu su yuzdendi:
%    - Tp=0.25s ile birbirine BITISIK (overlap'siz) FFT'ler
%    - Pencereleme yok (rectangular) -> kotu sidelobe
%    - Sadece 60 zaman bini
%
%  Bu surumde:
%    + Overlapping STFT (%95 overlap)         -> cok yumusak zaman ekseni
%    + Hann penceresi                          -> -50 dB sidelobe
%    + Zero-pad x8                             -> yumusak hiz ekseni
%    + Opsiyonel clutter rejection (DC notch)  -> statik yansimalar bastirilir
%
%  NOT: 192 kHz ornekleme yardim ETMEZ. Doppler frekansi cok dusuk
%  (40 m/s @ 2.25 GHz -> 600 Hz). 44.1 kHz Nyquist'i (22050 Hz)
%  zaten fazlasiyla yeterli. Cozunurluk Tp ile belirlenir, FS ile degil.
% =====================================================================

clear; close all; clc;

%% --- Kullanici parametreleri ---
filename = 'mit_style_capture.wav';

c       = 3e8;
fc      = 2250e6;       % CW carrier (VCO Vtune DC seviyesine gore)
lambda  = c / fc;

% STFT ayarlari
Tp              = 0.250;    % integrasyon suresi -> hiz cozunurlugu
overlap_ratio   = 0.95;     % %95 overlap (gorsel yumusaklik)
Nfft_mult       = 8;        % zero-pad carpani (hiz ekseni yumusakligi)
remove_clutter  = true;     % statik yansimalari (DC + cok dusuk hiz) bastir
notch_bins      = 3;        % bastirilacak dusuk-hiz bin sayisi

display_vmax    = 40;       % gosterilecek max hiz (m/s)
db_floor        = -45;      % renkbar min (dB)

%% --- .wav oku ---
[Y, FS] = audioread(filename);
fprintf('FS = %d Hz, sure = %.2f s\n', FS, size(Y,1)/FS);

if size(Y,2) >= 2
    s = -1 * Y(:,2);        % IF kanali (MIT konvensiyonu: invert)
else
    s = -1 * Y(:,1);
end
s = s - mean(s);            % DC bias temizle

%% --- STFT parametreleri ---
Nwin  = round(Tp * FS);
Nover = round(overlap_ratio * Nwin);
Nfft  = Nfft_mult * Nwin;

fprintf('Nwin=%d, Nover=%d, hop=%d (=%.3f s), Nfft=%d\n', ...
        Nwin, Nover, Nwin-Nover, (Nwin-Nover)/FS, Nfft);

%% --- Spectrogram (overlapping STFT) ---
% MATLAB built-in spectrogram; window = Hann
[S, F, T] = spectrogram(s, hann(Nwin), Nover, Nfft, FS);
% S boyutu: [Nfft/2+1 x num_time_bins], F: Hz (pozitif), T: saniye

%% --- Hz -> hiz donusumu ---
velocity = F * lambda / 2;          % m/s

%% --- Clutter rejection (opsiyonel): DC ve cok yavas yansimalari bastir ---
if remove_clutter
    S(1:notch_bins, :) = 0;
end

%% --- dB ve normalize ---
V_db = 20*log10(abs(S) + eps);
V_db = V_db - max(V_db(:));

%% --- Goster ---
figure('Color','w','Name','DTI - High Resolution');
imagesc(velocity, T, V_db.', [db_floor, 0]);
axis xy;
colormap(jet);
cb = colorbar; ylabel(cb, 'Magnitude (dB)');
xlim([0 display_vmax]);
xlabel('Velocity (m/s)');
ylabel('Time (s)');
title(sprintf(['DTI  |  Tp=%.2fs  overlap=%.0f%%  Hann  Nfft=%d' ...
               '  |  clutter=%s'], ...
              Tp, 100*overlap_ratio, Nfft, ...
              ternary(remove_clutter, 'ON', 'OFF')));

%% --- Cozunurluk raporu ---
fprintf('\n--- Cozunurluk ---\n');
fprintf('Hiz cozunurlugu       : %.3f m/s   (= lambda/(2*Tp))\n', ...
        lambda/(2*Tp));
fprintf('Zaman bin araligi     : %.4f s\n', (Nwin-Nover)/FS);
fprintf('Toplam zaman bini     : %d\n', length(T));
fprintf('Hiz bini (zero-pad)   : %.4f m/s\n', velocity(2)-velocity(1));
fprintf('Max algilanabilir hiz : %.1f m/s\n', max(velocity));

%% --- Yardimci ---
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

%% =====================================================================
%  AYAR IPUCLARI:
%
%  1) Hizli hedefler icin (araba, vs.):  Tp = 0.10..0.15 s
%     -> daha hizli zaman tepkisi, ama hiz cozunurlugu ~0.6-0.8 m/s
%
%  2) Yavas hedefler icin (yaya):  Tp = 0.30..0.50 s
%     -> daha iyi hiz ayirma, zaman ekseni biraz daha agir
%
%  3) Daha az "yumusatma" istersen overlap_ratio = 0.5 yap (klasik STFT)
%
%  4) Eger DC etrafinda parlak bir cizgi varsa: clutter sebep.
%     notch_bins'i 5-10 arasi artir.
%
%  5) Eger merkez frekansiniz tam emin degilseniz, bilinen bir hareketli
%     hedef ile (orn. yuruyen kisi @ 1.4 m/s) kalibre edin: tepe hiz
%     bin'i 1.4 m/s'de cikiyor olmali. Cikmiyorsa fc'yi duzeltin.
% =====================================================================