function prepare_data_v2()
% PREPARE_DATA_V2
% Random 70/15/15 image-level train/val/test split for OCT v2 U-Net.
%
% NOTE: Image-level split (not subject-level) because subject identifiers
% were lost when files were combined into a single folder. With ~12 images
% per subject and substantial spatial diversity between frames, leakage
% risk is mild but real. Document this as a limitation.
%
% Pairs '<base>_proc.png' (PNG folder) with '<base>_mask.png' (filled folder).

% -------- Config ---------------------------------------------------------
png_dir    = 'C:\OCT\Chosen Ones\preprocessed\use\segment\png';
filled_dir = 'C:\OCT\Chosen Ones\preprocessed\use\segment\filled';
out_file   = 'C:\OCT\Chosen Ones\preprocessed\use\segment\dataset_split_v2.mat';

frac_train = 0.70;
frac_val   = 0.15;
% test = remainder
rng_seed = 42;
% -------------------------------------------------------------------------

mask_files = dir(fullfile(filled_dir, '*_mask.png'));
if isempty(mask_files)
    error('No *_mask.png in %s', filled_dir);
end

img_paths = {};
lbl_paths = {};
bases     = {};
for k = 1:numel(mask_files)
    m_name = mask_files(k).name;
    base   = erase(m_name, '_mask.png');
    p_path = fullfile(png_dir,    [base '_proc.png']);
    m_path = fullfile(filled_dir, m_name);
    if ~exist(p_path, 'file'); continue; end
    img_paths{end+1} = p_path; %#ok<AGROW>
    lbl_paths{end+1} = m_path; %#ok<AGROW>
    bases{end+1}     = base;   %#ok<AGROW>
end

if isempty(img_paths)
    error('No paired (PNG, mask) files found.');
end

n = numel(img_paths);
fprintf('Total paired files: %d\n', n);

% --- Random image-level split ------------------------------------------
rng(rng_seed);
perm = randperm(n);

n_train = round(frac_train * n);
n_val   = round(frac_val   * n);
n_test  = n - n_train - n_val;

idx_train = perm(1:n_train);
idx_val   = perm(n_train+1 : n_train+n_val);
idx_test  = perm(n_train+n_val+1 : end);

train.img = img_paths(idx_train);  train.lbl = lbl_paths(idx_train);  train.base = bases(idx_train);
val.img   = img_paths(idx_val);    val.lbl   = lbl_paths(idx_val);    val.base   = bases(idx_val);
test.img  = img_paths(idx_test);   test.lbl  = lbl_paths(idx_test);   test.base  = bases(idx_test);

fprintf('\nSplit (seed=%d, image-level random %.0f/%.0f/%.0f):\n', ...
    rng_seed, 100*frac_train, 100*frac_val, 100*(1-frac_train-frac_val));
fprintf('  Train: %d images\n', n_train);
fprintf('  Val  : %d images\n', n_val);
fprintf('  Test : %d images\n', n_test);

fprintf('\nTest set files:\n');
for i = 1:numel(test.base)
    fprintf('  %s\n', test.base{i});
end

% --- Save --------------------------------------------------------------
classNames = ["bg", "sc", "ed"];
labelIDs   = [0, 1, 2];
save(out_file, 'train', 'val', 'test', 'classNames', 'labelIDs', 'rng_seed');
fprintf('\nSaved split -> %s\n', out_file);
fprintf('\n[Note] Image-level split: same subject may appear in train+test.\n');
fprintf('       Test Dice may be slightly optimistic; document as limitation.\n');
end