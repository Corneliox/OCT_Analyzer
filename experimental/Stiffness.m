clc;
clear all;
close all;

%% 0. Force Light Theme (R2025b dark mode workaround)
set(groot, 'DefaultFigureColor'    , 'w');
set(groot, 'DefaultAxesColor'      , 'w');
set(groot, 'DefaultAxesXColor'     , 'k');
set(groot, 'DefaultAxesYColor'     , 'k');
set(groot, 'DefaultAxesZColor'     , 'k');
set(groot, 'DefaultAxesGridColor'  , [.3 .3 .3]);
set(groot, 'DefaultTextColor'      , 'k');
set(groot, 'DefaultLegendColor'    , 'w');
set(groot, 'DefaultLegendTextColor', 'k');
set(groot, 'DefaultLegendEdgeColor', 'k');

%% 1. Membaca File CSV
filename = 'C:\OCT\test\2_analysis\timeseries.csv';

if ~exist(filename, 'file')
    error('File %s tidak ditemukan! Pastikan file berada di folder yang sama.', filename);
end

% Membaca tabel
data = readtable(filename);

% Mengambil data (Kolom 5 untuk E, Kolom 7 untuk G)
data_E = data{:, 5} * -1;
data_G = data{:, 7} * -1;

%% 2. Visualisasi Awal
fig1 = figure('Name', 'Analisis Skin Thickness', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.05 0.1 0.6 0.8]);
ax_pick = subplot(3, 1, 1);
plot(ax_pick, data_E, 'b', 'LineWidth', 1.5); hold(ax_pick, 'on');
plot(ax_pick, data_G, 'r', 'LineWidth', 1.5);
title(ax_pick, 'Skin Thickness Analysis');
ylabel(ax_pick, 'mm');
grid(ax_pick, 'on');
legend(ax_pick, 'Data E', 'Data G');

%% 3. Sesi Pemilihan Titik MAKSIMUM (Klik 1 & 2)
% Diganti dari ginput ke waitforbuttonpress karena bug cursor di R2025b.
disp('--- SESI 1 ---');
disp('Klik 2x pada grafik ATAS untuk batas KIRI dan KANAN area MAKSIMUM.');

x_max_klik = zeros(2, 1);
c = 0;
while c < 2
    fprintf('Klik %d/2 ...\n', c+1);
    figure(fig1);
    waitforbuttonpress;
    cp = get(ax_pick, 'CurrentPoint');
    xc = cp(1,1); yc = cp(1,2);
    xl = xlim(ax_pick); yl = ylim(ax_pick);
    if xc < xl(1) || xc > xl(2) || yc < yl(1) || yc > yl(2)
        fprintf('   (klik di luar grafik atas, abaikan - klik lagi)\n');
        continue;
    end
    c = c + 1;
    x_max_klik(c) = xc;
    plot(ax_pick, xc, yc, 'kx', 'MarkerSize', 14, 'LineWidth', 2);
    drawnow;
end

idx_awal_max  = round(min(x_max_klik));
idx_akhir_max = round(max(x_max_klik));

% Proteksi indeks agar tidak keluar batas array
idx_awal_max  = max(1, idx_awal_max);
idx_akhir_max = min(length(data_E), idx_akhir_max);

% Analisis Maksimum di area terpilih
area_max = data_E(idx_awal_max:idx_akhir_max);
[val_max, rel_idx_max] = max(area_max);
idx_max_global = idx_awal_max + rel_idx_max - 1;

% Mencari titik paling kanan dengan toleransi 2
toleransi = 2;
idx_tol = find(area_max >= (val_max - toleransi) & area_max <= (val_max + toleransi));
idx_kanan_max = idx_awal_max + idx_tol(end) - 1;
val_kanan_max = data_E(idx_kanan_max);

% Plot hasil Maksimum
line(ax_pick, [idx_awal_max idx_awal_max],   ylim(ax_pick), 'Color', [0 0.5 0], 'LineStyle', '--', 'HandleVisibility', 'off');
line(ax_pick, [idx_akhir_max idx_akhir_max], ylim(ax_pick), 'Color', [0 0.5 0], 'LineStyle', '--', 'HandleVisibility', 'off');
plot(ax_pick, idx_max_global, val_max, 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 12, 'DisplayName', 'Titik Max Absolut');
plot(ax_pick, idx_kanan_max, val_kanan_max, 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Titik Kanan (Tol 2)');

%% 4. Sesi Pemilihan Titik MINIMUM (Klik 3 & 4)
disp('--- SESI 2 ---');
disp('Klik 2x pada grafik ATAS untuk batas KIRI dan KANAN area MINIMUM.');

x_min_klik = zeros(2, 1);
c = 0;
while c < 2
    fprintf('Klik %d/2 ...\n', c+1);
    figure(fig1);
    waitforbuttonpress;
    cp = get(ax_pick, 'CurrentPoint');
    xc = cp(1,1); yc = cp(1,2);
    xl = xlim(ax_pick); yl = ylim(ax_pick);
    if xc < xl(1) || xc > xl(2) || yc < yl(1) || yc > yl(2)
        fprintf('   (klik di luar grafik atas, abaikan - klik lagi)\n');
        continue;
    end
    c = c + 1;
    x_min_klik(c) = xc;
    plot(ax_pick, xc, yc, 'kx', 'MarkerSize', 14, 'LineWidth', 2);
    drawnow;
end

idx_awal_min  = round(min(x_min_klik));
idx_akhir_min = round(max(x_min_klik));

% Proteksi indeks
idx_awal_min  = max(1, idx_awal_min);
idx_akhir_min = min(length(data_E), idx_akhir_min);

% Analisis Minimum di area terpilih (Murni tanpa toleransi)
area_min = data_E(idx_awal_min:idx_akhir_min);
[val_min, rel_idx_min] = min(area_min);
idx_min_global = idx_awal_min + rel_idx_min - 1;

% Plot hasil Minimum
line(ax_pick, [idx_awal_min idx_awal_min],   ylim(ax_pick), 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
line(ax_pick, [idx_akhir_min idx_akhir_min], ylim(ax_pick), 'Color', 'r', 'LineStyle', '--', 'HandleVisibility', 'off');
plot(ax_pick, idx_min_global, val_min, 'kv', 'MarkerFaceColor', 'c', 'MarkerSize', 10, 'DisplayName', 'Titik Min Absolut');

% Update Legend agar rapi
legend(ax_pick, 'Location', 'northeastoutside');

%% 5. Kalibrasi dan Penyimpanan Data (Deformation)
% Catatan: section 5 sebelumnya yang membuat 'deformation_table' versi pixel
% sudah dihapus karena di-overwrite oleh blok ini (versi µm).
start_idx = min(idx_max_global, idx_min_global);
end_idx   = max(idx_max_global, idx_min_global);

% 1. Ekstraksi data mentah (Pixel)
raw_E      = data_E(start_idx:end_idx);
raw_G      = data_G(start_idx:end_idx);
raw_index  = (0:(end_idx - start_idx))';

% 2. Konversi Sumbu X (Waktu: detik)
fps      = 25;
time_sec = raw_index / fps;

% 3. Konversi Sumbu Y (Kedalaman: mikrometer)
% Faktor: (pixel / 200) * 1000 -> pixel * 5
pixel_to_um       = 1000 / 200;
deformation_E_um  = raw_E * pixel_to_um;
deformation_G_um  = raw_G * pixel_to_um;

% 4. Hitung Thickness dalam mikrometer
thickness_um = deformation_E_um - deformation_G_um;

% Membuat Tabel Final
deformation_table = table(time_sec, deformation_E_um, deformation_G_um, thickness_um, ...
    'VariableNames', {'Time_sec', 'Skin_Surface_um', 'Skin_Base_um', 'Thickness_um'});

%% 6. Visualisasi Hasil Kalibrasi (Subplot 2 & 3)
ax2 = subplot(3, 1, 2);
plot(ax2, time_sec, thickness_um, 'k', 'LineWidth', 1.5);
title(ax2, 'Calibrated Skin Thickness over Time');
xlabel(ax2, 'Time (seconds)');
ylabel(ax2, 'Thickness (\mum)');
grid(ax2, 'on');

ax3 = subplot(3, 1, 3);
plot(ax3, time_sec, deformation_E_um, 'b', 'LineWidth', 1.2); hold(ax3, 'on');
plot(ax3, time_sec, deformation_G_um, 'r', 'LineWidth', 1.2);
title(ax3, 'Skin Layers Position');
xlabel(ax3, 'Time (seconds)');
ylabel(ax3, 'Depth (\mum)');
grid(ax3, 'on');
legend(ax3, 'Surface (E)', 'Base (G)');

sgtitle(['Analysis Result: ', filename], 'FontSize', 12, 'FontWeight', 'bold');

% 1. Variabel force placeholder (0 sampai 0.1 gram, akan diganti dengan sensor asli)
num_points              = length(thickness_um);
force_gram              = linspace(0, 0.1, num_points)';
deformation_table.Force_gram = force_gram;

%% 7. Curve Fitting (Force vs Thickness)
% Sumbu X: Thickness deformation, Sumbu Y: Force
x_data = thickness_um - thickness_um(1);
y_data = force_gram;

% Polyfit ORDE 2 (kuadratik); p(1)=koef x^2, p(2)=koef x, p(3)=konstanta
p = polyfit(x_data, y_data, 2);

thickness_new = linspace(min(x_data), max(x_data), 100)';
force_new     = polyval(p, thickness_new);

%% 8. Visualisasi pada Figure Baru (Fitting Analysis)
fig2 = figure('Name', 'Analisis Curve Fitting: Force vs Thickness', ...
    'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'normalized', 'Position', [0.06 0.15 0.45 0.7]);

plot(x_data, y_data, 'ko', 'MarkerSize', 4, 'DisplayName', 'Data Awal (Hasil Klik)');
hold on;
plot(thickness_new, force_new, 'r-', 'LineWidth', 2, 'DisplayName', 'Garis Fungsi (Fitting)');
plot(thickness_new, force_new, 'bx', 'MarkerSize', 5, 'DisplayName', '100 Titik Baru');

% PERBAIKAN: judul sebelumnya tertulis "Order 1" padahal polyfit orde 2.
title('Korelasi Force vs Thickness (Polyfit Order 2)');
xlabel('Thickness (\mum)');
ylabel('Force (gram)');
grid on;
legend('Location', 'best');

% PERBAIKAN: persamaan sebelumnya hanya menampilkan 2 koefisien (linear),
% padahal polyfit orde 2 menghasilkan 3 koefisien. Sekarang ditampilkan
% lengkap: y = a*x^2 + b*x + c.
equation_str = sprintf('y = %.6fx^2 + %.6fx + %.6f', p(1), p(2), p(3));
text(min(thickness_new), max(force_new)*0.9, equation_str, ...
    'FontSize', 11, 'Color', 'r', 'FontWeight', 'bold', 'BackgroundColor', 'w');

%% 9. Stiffness (Hayes/Zheng-Mak: E1, E2, E3, E23)
% =============================================================
% Hitung modulus elastisitas pada strain 5%, 10%, 15% menggunakan
% formula Hayes (Zheng & Mak, 1999):
%
%      E = (1 - nu^2) * F  /  (2 * a * kappa * w)
%
%  F     = gaya indentasi (kgf)
%  w     = kedalaman indentasi (mm)
%  a     = radius indentor (mm)
%  h     = ketebalan jaringan (mm)
%  nu    = Poisson's ratio
%  kappa = faktor skala geometrik (fungsi a/h, dari tabel)
%
%  Faktor 9.807: konversi kgf/mm^2 -> MPa.
% =============================================================

% Konstanta material dan indentor
nu            = 0.45;       % Poisson's ratio (jaringan lunak)
a_indenter    = 2.5;        % radius indentor (mm)
strain_ratios = [0.05, 0.10, 0.15];

% Tabel kappa (a/h vs kappa, untuk nu mendekati 0.5)
kappa_tbl = [0.2 1.252; 0.4 1.599; 0.6 2.031; 0.8 2.532; 1.0 3.085;
             1.5 4.638; 2.0 6.380; 2.5 8.265; 3.0 10.260; 3.5 12.320;
             4.0 14.450; 5.0 18.800; 6.0 23.230; 7.0 27.690; 8.0 32.150];

% Konversi ke unit Hayes (mm, kg)
% Catatan: thickness_um(1) adalah baseline (frame paling tidak tertekan)
h0_mm    = thickness_um(1) / 1000;                          % baseline thickness (mm)
def_mm   = (thickness_um(1) - thickness_um) / 1000;         % deformasi positif saat tertekan
force_kg = force_gram / 1000;                                % gram -> kg

% Polyfit force(kg) vs deformation(mm) -- urutan untuk Hayes
p_hayes = polyfit(def_mm, force_kg, 2);
max_def = max(def_mm);

% Hitung kappa via interpolasi tabel
a_h   = a_indenter / h0_mm;
kappa = interp1(kappa_tbl(:,1), kappa_tbl(:,2), a_h, 'linear', 'extrap');

% Faktor: (1-nu^2) / (2*a*kappa) * 9.807  -> MPa (jika F kg, w mm)
e_factor = (1 - nu^2) / (2 * a_indenter * kappa) * 9.807;

% Hitung E1, E2, E3 pada strain 5%, 10%, 15%
W = h0_mm * strain_ratios;          % kedalaman indentasi target (mm)
F = polyval(p_hayes, W);            % gaya pada kedalaman tsb (kg, dari polyfit)
E = (F ./ W) * e_factor;            % modulus elastisitas (MPa)
is_extrap = W > max_def;            % flag jika titik diluar data observasi

% Modulus secant E23 (10% - 15%)
E23 = (F(3) - F(2)) / (W(3) - W(2)) * e_factor;

% --- Print ke command window ---
fprintf('\n========== STIFFNESS RESULTS (Hayes/Zheng-Mak) ==========\n');
fprintf('Baseline thickness h0   = %.4f mm  (%.1f um)\n', h0_mm, thickness_um(1));
fprintf('Indenter radius a       = %.2f mm\n', a_indenter);
fprintf('a/h ratio               = %.2f\n', a_h);
fprintf('Kappa (table interp)    = %.2f\n', kappa);
fprintf('Max strain reached      = %.1f%%\n', 100*max_def/h0_mm);
if a_h > 8
    fprintf('NOTE: a/h > 8 (tabel maks 8); kappa diekstrapolasi.\n');
end
fprintf('----------------------------------------------------------\n');
for k = 1:3
    note = ''; if is_extrap(k), note = ' [EXTRAPOLATED]'; end
    fprintf('E%d (strain %2d%%, w=%.4f mm) = %.4f MPa%s\n', ...
        k, round(100*strain_ratios(k)), W(k), E(k), note);
end
fprintf('E23 (secant 10%%-15%%)        = %.4f MPa\n', E23);
fprintf('==========================================================\n');
fprintf('NOTE: force_gram = linspace(0, 0.1) masih placeholder.\n');
fprintf('Ganti dengan data load-cell asli untuk MPa yang valid.\n\n');

%% 10. Visualisasi Stiffness (figure baru)
fig3 = figure('Name', 'Stiffness Analysis (Hayes)', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.52 0.15 0.45 0.7]);
ax_s = axes(fig3, 'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
hold(ax_s, 'on');

% Scatter data observasi
plot(ax_s, def_mm, force_kg, 'o', 'MarkerEdgeColor', [.2 .2 .2], ...
    'MarkerFaceColor', [.7 .7 .7], 'MarkerSize', 5, 'DisplayName', 'Data observasi');

% Polyfit: solid dalam range data, dashed di ekstrapolasi
xmax_curve = max([max_def, W]);
xi = linspace(0, xmax_curve, 300);
fi = polyval(p_hayes, xi);
in_range = xi <= max_def;
plot(ax_s, xi(in_range), fi(in_range), 'k-', 'LineWidth', 2, 'DisplayName', 'Polyfit (in-range)');
if any(~in_range)
    plot(ax_s, xi(~in_range), fi(~in_range), '--', 'Color', [.5 .5 .5], 'LineWidth', 1.3, ...
        'DisplayName', 'Polyfit (extrapolated)');
end

% Marker E1, E2, E3
cols = lines(3);
for k = 1:3
    if is_extrap(k)
        plot(ax_s, W(k), F(k), 's', 'MarkerEdgeColor', cols(k,:), ...
            'MarkerFaceColor', 'w', 'MarkerSize', 12, 'LineWidth', 2, ...
            'DisplayName', sprintf('E_%d (extrapolated)', k));
        lbl = sprintf('  E_%d = %.3f MPa*', k, E(k));
    else
        plot(ax_s, W(k), F(k), 's', 'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', cols(k,:), 'MarkerSize', 11, ...
            'DisplayName', sprintf('E_%d', k));
        lbl = sprintf('  E_%d = %.3f MPa', k, E(k));
    end
    text(ax_s, W(k), F(k), lbl, 'Color', cols(k,:), 'FontWeight', 'bold');
end

xlabel(ax_s, 'Deformation (mm)');
ylabel(ax_s, 'Force (kg)');
title(ax_s, sprintf( ...
    'Stiffness:  h_0 = %.3f mm   max strain = %.1f%%   E_{23} = %.4f MPa   (* = extrapolated)', ...
    h0_mm, 100*max_def/h0_mm, E23));
grid(ax_s, 'on');
legend(ax_s, 'Location', 'northwest');

% --- Simpan tabel hasil stiffness ---
stiffness_table = table( ...
    {'E1';'E2';'E3';'E23'}, ...
    [W'; NaN], ...
    [F'; NaN], ...
    [E'; E23], ...
    [is_extrap'; is_extrap(2) || is_extrap(3)], ...
    'VariableNames', {'Name','Deformation_mm','Force_kg','Modulus_MPa','Extrapolated'});
disp(stiffness_table);