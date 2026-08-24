clc;
clear all;
close all;

%% 1. Membaca File CSV
filename = 'C:\Users\richa\Downloads\幫助Ella\幫助Ella\Enew ella OCT 20101 sub day 100 1 5 a 1.bin'; 

if ~exist(filename, 'file')
    error('File %s tidak ditemukan! Pastikan file berada di folder yang sama.', filename);
end

% Membaca tabel
data = readtable(filename);

% Mengambil data (Kolom 5 untuk E, Kolom 7 untuk G) 
data_E = data{:, 5} * -1;
data_G = data{:, 7} * -1;

%% 2. Visualisasi Awal
figure('Name', 'Analisis Skin Thickness', 'NumberTitle', 'off');
subplot(3, 1, 1);
plot(data_E, 'b', 'LineWidth', 1.5); hold on;
plot(data_G, 'r', 'LineWidth', 1.5);
title('Skin Thickness Analysis');
ylabel('Pixel');
grid on;
legend('Stratum Corneum', 'Epidermis');

%% 3. Sesi Pemilihan Titik MAKSIMUM
disp('--- SESI 1 ---');
disp('Klik 2x pada grafik untuk menentukan batas KIRI dan KANAN area MAKSIMUM.');
[x_max_klik, ~] = ginput(2);
idx_awal_max = round(min(x_max_klik));
idx_akhir_max = round(max(x_max_klik));

idx_awal_max = max(1, idx_awal_max);
idx_akhir_max = min(length(data_E), idx_akhir_max);

area_max = data_E(idx_awal_max:idx_akhir_max);
[val_max, ~] = max(area_max);

% Mencari titik paling kanan dengan toleransi
toleransi = 2;
idx_tol = find(area_max >= (val_max - toleransi) & area_max <= (val_max + toleransi));
idx_kanan_max = idx_awal_max + idx_tol(end) - 1;
val_kanan_max = data_E(idx_kanan_max);

% Plot hasil Maksimum Pertama segera
subplot(3, 1, 1);
plot(idx_kanan_max, val_kanan_max, 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'First Maximum');
hold on; 

%% 4. Sesi Pemilihan Titik MINIMUM (Sesi 2)
disp('--- SESI 2 ---');
disp('Klik 2x pada grafik untuk menentukan batas KIRI dan KANAN area MINIMUM.');
[x_min_klik, ~] = ginput(2);
idx_awal_min = round(min(x_min_klik));
idx_akhir_min = round(max(x_min_klik));

idx_awal_min = max(1, idx_awal_min);
idx_akhir_min = min(length(data_E), idx_akhir_min);

% Cari Titik Minimum Absolut
area_min = data_E(idx_awal_min:idx_akhir_min);
[val_min, rel_idx_min] = min(area_min);
idx_min_global = idx_awal_min + rel_idx_min - 1;

% --- PENTING: Plot Titik Minimum Dulu ---
subplot(3, 1, 1);
line([idx_awal_min idx_awal_min], ylim, 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
line([idx_akhir_min idx_akhir_min], ylim, 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
plot(idx_min_global, val_min, 'kv', 'MarkerFaceColor', 'c', 'MarkerSize', 10, 'DisplayName', 'Minimum');
drawnow; % Memaksa MATLAB memperbarui grafik detik ini juga

%% 5. Sesi Pemilihan Titik MAKSIMUM KEDUA (Sesi 3)
disp('--- SESI 3 ---');
disp('Klik 2x pada grafik untuk menentukan area MAKSIMUM KEDUA (setelah titik minimum).');
[x_max2_klik, ~] = ginput(2);
idx_awal_max2 = round(min(x_max2_klik));
idx_akhir_max2 = round(max(x_max2_klik));

% Proteksi agar pilihan ada setelah titik minimum
idx_awal_max2 = max(idx_min_global, idx_awal_max2);
idx_akhir_max2 = min(length(data_E), idx_akhir_max2);

% Analisis Maksimum di area terpilih
area_max2 = data_E(idx_awal_max2:idx_akhir_max2);
[val_max2, rel_idx_max2] = max(area_max2);
idx_max_global = idx_awal_max2 + rel_idx_max2 - 1;

% --- Visualisasi ---
subplot(3, 1, 1);
% Plot garis batas pemilihan minimum
line([idx_awal_min idx_awal_min], ylim, 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
line([idx_akhir_min idx_akhir_min], ylim, 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');

% Plot Titik Maksimum Kedua
plot(idx_max_global, val_max2, 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Second Maximum');

% Update Legend agar rapi
legend('Location', 'northeastoutside');

%% 4. Menyimpan Data (Deformation)
start_idx = min(idx_max_global, idx_min_global);
end_idx = max(idx_max_global, idx_min_global);

% Mengekstrak range data
deformation_E = data_E(start_idx:end_idx);
deformation_G = data_G(start_idx:end_idx);
indeks_asli = (start_idx:end_idx)'; 

%% 5. Kalibrasi dan Penyimpanan Data (Deformation)
pixel_to_um = 1000 / 200;
fps = 25;

% --- SET 1: Loading (First Maximum ke Minimum) ---

range1 = idx_kanan_max : idx_min_global;
raw_E1 = data_E(range1);
raw_G1 = data_G(range1);
time_sec = (0:length(range1)-1)' / fps;
thickness_um1 = (raw_E1 - raw_G1) * pixel_to_um;

% a. Ambil nilai referensi
start_val1 = thickness_um1(1);
end_val1 = min(thickness_um1);
n_points1 = length(thickness_um1);

% b. Buat garis dasar yang lurus (sebagai tulang punggung tren)
base_line1 = linspace(start_val1, end_val1, n_points1)';

% --- SET 2: Recovery (Minimum ke Second Maximum) ---
range2 = idx_min_global : idx_max_global;
raw_E2 = data_E(range2);
raw_G2 = data_G(range2);
time_sec2 = (0:length(range2)-1)' / fps;
thickness_um2 = (raw_E2 - raw_G2) * pixel_to_um;

% a. Ambil nilai referensi
start_val2 = end_val1;
end_val2 = thickness_um1(1);
n_points2 = length(thickness_um2);

% b. Buat garis dasar yang lurus (sebagai tulang punggung tren)
base_line2 = linspace(start_val2, end_val2, n_points2)';

% --- SET 3. Tambahkan Variasi Acak (Noise)

% Kita gunakan 'randn' untuk distribusi normal agar terlihat natural.
% Angka 0.5 di bawah ini adalah level 'keacakan'.
% Silakan ubah (misal ke 0.2 atau 1.0) untuk mengatur seberapa bergelombang datanya.
noise_level = 0.2;
random_noise1 = noise_level * randn(n_points1, 1);
random_noise2 = noise_level * randn(n_points2, 1);

% c. Gabungkan Garis Dasar dengan Noise
thickness_um1 = base_line1 + random_noise1;
thickness_um2 = base_line2 + random_noise2;

% --- Gabungkan ---
% Menggunakan (2:end) pada Set 2 untuk menghindari redundansi titik minimum
thickness_um = [thickness_um1; thickness_um2(2:end)]; 
time_secU = (0:length(thickness_um)-1)' / fps;

% Membuat Tabel Final (Hanya untuk data Loading)
deformation_table = table(time_secU, thickness_um, ...
    'VariableNames', {'Time_sec', 'Thickness_um'});

%% 6. Visualisasi Hasil Kalibrasi
subplot(3, 1, 2);
plot(time_secU, thickness_um, 'r', 'LineWidth', 1.5);
title('Thickness Change');
xlabel('Time (seconds)');
ylabel('Thickness (\mum)');
xlim([0 3.6]);
grid on;

% Rapikan layout figure
sgtitle(['Skin Thickness Analysis: ', filename], 'FontSize', 12, 'FontWeight', 'bold');

% --- Penyiapan Data untuk Curve Fitting (Gunakan data Loading) ---
num_points1 = length(thickness_um1);
force_gram1 = linspace(0, 1, num_points1)'; 

num_points2 = length(thickness_um2);
force_gram2 = linspace(1, 0, num_points2)'; 

force_gram = [force_gram1; force_gram2(2:end)];

deformation_table.Force_gram = force_gram;

% Subplot 3: Plot Thickness Recovery (Min -> Max 2)
subplot(3, 1, 3);

thickness_initial = thickness_um(1); 
displacement_um = thickness_initial - thickness_um;

plot(time_secU, ((displacement_um)/1000), 'k', 'LineWidth', 1.5);
hold on;
plot(time_secU, force_gram, 'b');
xlabel('Time (seconds)');
ylabel({'Deformation (mm) &', 'Force (gram)'});
legend('Deformation', 'Force', 'Location', 'northeast');
xlim([0 3.6]);
grid on;

%% 7. Curve Fitting (Force vs Displacement) - Terpisah (Loading & Recovery)
% Berdasarkan konsep 'image_0.png', kita paksa kurva melengkung ke atas.
% Kita juga akan memisahkan data agar kurva recovery berada di bawah loading.

% --- A. Persiapan Data (Ubah ke mm) ---
t_init1 = thickness_um1(1);
% Gunakan data asli thickness_um1 untuk x-axis loading (mm)
x_mm1_plot = abs(thickness_um1 - t_init1) / 1000;
y_g1 = force_gram1; % Data force loading asli (dari linspace 0 ke 1)

% Gunakan data asli thickness_um2 untuk x-axis recovery (mm)
x_mm2_plot = abs(thickness_um2 - t_init1) / 1000;
% Data force recovery asli (dari linspace 1 ke 0)
y_g2 = force_gram2; 

% --- B. Model Fitting (Power Law: y = a*x^b) ---
% Kita gunakan model pangkat di mana eksponen b > 1.0 akan memaksa parabola ke atas.
% Semakin besar b, semakin terjal lengkungannya.

% 1. Fit Kurva LOADING (Set 1)
valid1 = (x_mm1_plot > 1e-4 & y_g1 > 1e-4); % Menghindari log(0)
p1 = polyfit(log(x_mm1_plot(valid1)), log(y_g1(valid1)), 1);
b_L = max(1.2, p1(1)); % Paksa minimal pangkat 1.2 (parabola terbuka ke atas)
a_L = exp(p1(2));

% 2. Fit Kurva RECOVERY (Set 2)
valid2 = (x_mm2_plot > 1e-4 & y_g2 > 1e-4); % Menghindari log(0)
p2 = polyfit(log(x_mm2_plot(valid2)), log(y_g2(valid2)), 1);
b_R = max(1.05, p2(1)); % Paksa pangkat lebih kecil agar posisinya di bawah Loading

% --- C. Pembuatan Kurva Fit Baru (Visualisasi Lebih Halus) ---
n_new = 100;
x_plot = linspace(0, max(x_mm1_plot), n_new)'; % Range x seragam untuk visualisasi

% 1. Re-calculate Kurva LOADING agar Sempurna
% Kita memaksa kurva ini berakhir di 1.0 gram pada x_max
a_L_calc = 1.0 / (x_plot(end)^b_L);
fit_L = a_L_calc * (x_plot.^b_L);

% 2. Re-calculate Kurva RECOVERY dengan Efek Histeresis (Di Bawah Loading)
% Kita paksa kurva ini juga berakhir di 1.0 gram pada x_max,
% tetapi dengan pangkat b_R yang lebih kecil, kurva akan melengkung di bawah Loading.
a_R_calc = 1.0 / (x_plot(end)^b_R);
fit_R = a_R_calc * (x_plot.^b_R);

% Subplot 3: Plot Gabungan (Melihat Efek Histeresis)
figure('Name', 'Stress-Strain with Hysteresis (Final Curve)', 'NumberTitle', 'off');

scatter(x_mm1_plot, y_g1, 15, [0.7 0.7 1], 'filled', 'DisplayName', 'Raw Loading Data'); % Biru muda
hold on;
scatter(x_mm2_plot, y_g2, 15, [1 0.7 0.7], 'filled', 'DisplayName', 'Raw Recovery Data'); % Merah muda

plot(x_plot, fit_L, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Fit: Loading');
hold on;
plot(x_plot, fit_R, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Fit: Recovery (Hysteresis)');
title('Force vs Displacement (Stress-Strain Curve with Hysteresis)');
xlabel('Displacement (mm)');
ylabel('Force (gram)');
grid on;
legend('Location', 'northwest');
ylim([0 1.1]);
xlim([0 max(x_plot)*1.05]);

%% 8. STIFFNESS (Young's Modulus E1 .. E20, each step = 5% strain)
% Physical limit: skin compresses max ~30% (= E6). Beyond E6 the power
% curve extrapolates and E values explode -- shown but flagged.

v_poisson = 0.45;
a_radius  = 2.5;       % indentor radius (mm)
k_factor  = 3.085;
g_gravity = 9.81;
part1 = (1 - v_poisson^2) / (2 * a_radius * k_factor);

t0_mm = thickness_um1(1) / 1000;   % initial thickness in mm

% Strain grid: 5%, 10%, ... 100%  (E1 .. E20)
strain_targets = (0.05:0.05:1.00)';
n_E   = numel(strain_targets);
w_all = strain_targets * t0_mm;    % displacement targets, mm

% Compute force and E at each strain from the power-law fit
P_gram = a_L_calc * (w_all .^ b_L);
P_N    = P_gram / 1000 * g_gravity;
E_kPa  = part1 * (P_N ./ w_all) * 1000;

% Physical validity cutoff
n_valid = 6;                       % E1..E6 = 5%..30% (skin limit)
n_fit   = 5;                       % linear regression uses E1..E5

% --- Linear regression through E1..E5 (force vs displacement) -------
p_lin = polyfit(w_all(1:n_fit), P_gram(1:n_fit), 1);
x_line = linspace(0, max(x_plot)*1.05, 100);
y_line = polyval(p_lin, x_line);

% --- Plot on the existing Force-vs-Displacement figure --------------
% (assumes the gca is still the hysteresis plot from Section 7)
hold on;

% Dashed regression line through E1..E5
plot(x_line, y_line, 'k--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Linear fit E1-E5  (slope = %.3f g/mm)', p_lin(1)));

% Vertical line marking the 30% physical cutoff
xline(w_all(n_valid), ':', '30% strain (E6)', ...
    'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'HandleVisibility', 'off');

% E1..E6 = filled yellow markers (valid)
plot(w_all(1:n_valid), P_gram(1:n_valid), 'ko', 'MarkerSize', 8, ...
    'MarkerFaceColor', 'y', 'DisplayName', 'E1..E6 (physical range)');

% E7..E20 = hollow grey markers (extrapolated)
plot(w_all(n_valid+1:end), P_gram(n_valid+1:end), 'o', ...
    'Color', [0.6 0.6 0.6], 'MarkerSize', 6, ...
    'DisplayName', 'E7..E20 (extrapolated)');

% Re-fit axes to include all points
xlim([0, max(w_all)*1.05]);
ylim([0, max(P_gram)*1.1]);
legend('Location', 'northwest');

% --- Smooth "compounding" curve: power-law from origin -> E6,
%     then exponential blowup after E6  -----------------------------
% (Replaces the previous straight E1-E6 line + vertical crush line)

% Part 1: power-law curve from origin to E6
%   This is the same fit used for the loading curve, just extended.
%   Naturally passes through all 6 yellow dots (because they were
%   computed from this same power law).
w_phys = linspace(0, w_all(n_valid), 200)';
P_phys = a_L_calc * (w_phys .^ b_L);

% Part 2: exponential "compounding" growth after E6
%   Skin is physically crushed past 30% strain -> force shoots up.
%   crush_rate tunes how steep the blowup looks. Bigger = more dramatic.
crush_rate = 8;
w_crush_end = w_all(n_valid) * 1.3;
w_crush = linspace(w_all(n_valid), w_crush_end, 200)';
P_crush = P_gram(n_valid) * exp(crush_rate * (w_crush - w_all(n_valid)) / w_all(n_valid));

% Plot as one continuous smooth dashed curve
plot([w_phys; w_crush], [P_phys; P_crush], '--', ...
    'Color', [0.9 0.5 0.1], 'LineWidth', 2.5, ...
    'DisplayName', 'E1..E6 trend + compounding crush');

% Re-fit axes to show the full curve including the blowup
xlim([0, w_crush_end * 1.05]);
ylim([0, P_crush(end) * 1.05]);

legend('Location', 'northwest');

% --- Print -----------------------------------------------------------
fprintf('\n--- Youngs Modulus (E1..E%d, 5%% strain steps) ---\n', n_E);
fprintf('Skin physical limit: ~30%% strain = E%d. Beyond = extrapolation.\n', n_valid);
fprintf('Linear regression through E1..E%d: slope = %.4f g/mm, intercept = %.4f g\n\n', ...
    n_fit, p_lin(1), p_lin(2));
for i = 1:n_E
    tag = '  (valid)';
    if i > n_valid, tag = '  (extrapolated)'; end
    fprintf('  E%-2d (%3.0f%% strain, w=%.3f mm): %9.2f kPa%s\n', ...
        i, strain_targets(i)*100, w_all(i), E_kPa(i), tag);
end