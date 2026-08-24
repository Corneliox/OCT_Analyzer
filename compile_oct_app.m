function compile_oct_app()
% COMPILE_OCT_APP
% Compile the OCT Analyzer GUI into a standalone Windows .exe.
%
% Prerequisites:
%   1. MATLAB Compiler license: license('test', 'Compiler') == 1
%   2. All pipeline files in the same folder as this script:
%      - OCTAnalyzerApp.m         (the GUI)
%      - batch_analyze_tree.m     (recursive overnight driver)
%      - analyze_stimulation_run.m
%      - segment_new_images.m
%      - extract_boundaries_dp.m
%      - check_segmentation.m
%      - preprocess_image_only.m
%   3. Trained Variant A model accessible at the hardcoded path
%      (it gets bundled into the exe - see below)
%
% Output:
%   - <output_dir>/OCTAnalyzer.exe
%
% Usage:
%   >> compile_oct_app
%   ... wait 5-15 minutes ...
%
% After compilation, give users:
%   - The .exe (model is bundled inside it)
%   - One-time MATLAB Runtime R2025b install (~3GB, free):
%     https://www.mathworks.com/products/compiler/matlab-runtime.html

% -------- Config -------------------------------------------------------
app_name      = 'OCTAnalyzer';
main_file     = 'OCTAnalyzerApp.m';
output_dir    = 'C:\Lab_or_Uni\OCT\test\exe\OCTAnalyzer_build';

% Auto-include all pipeline .m files + the trained model
extra_files = {
    'batch_analyze_tree.m'
    'analyze_stimulation_run.m'
    'segment_new_images.m'
    'extract_boundaries_dp.m'
    'check_segmentation.m'
    'preprocess_image_only.m'
};

% Path to the trained Variant A model - bundled into the exe so the GUI
% finds it regardless of the user's drive layout.
model_search_path = 'C:\Lab_or_Uni\OCT\test\exe\trained_variantA';
% -----------------------------------------------------------------------

if license('test', 'Compiler') == 0
    error(['MATLAB Compiler license not found. Run ', ...
        'license(''test'', ''Compiler'') to verify.']);
end

% --- Verify all required files exist ----------------------------------
all_files = [{main_file}, extra_files(:)'];
for i = 1:numel(all_files)
    if ~exist(all_files{i}, 'file')
        error('Required file missing: %s\nMake sure you cd to the folder containing all pipeline .m files first.', all_files{i});
    end
end

% --- Find latest trained model ----------------------------------------
mdl = dir(fullfile(model_search_path, 'unet_variantA_*.mat'));
if isempty(mdl)
    error('No trained model (unet_variantA_*.mat) found in %s', model_search_path);
end
[~, ix] = max([mdl.datenum]);
model_path = fullfile(model_search_path, mdl(ix).name);
fprintf('Bundling model: %s\n', model_path);

% --- Set up build folder ----------------------------------------------
if exist(output_dir, 'dir')
    fprintf('Cleaning previous build...\n');
    rmdir(output_dir, 's');
end
mkdir(output_dir);

% --- Compile -----------------------------------------------------------
fprintf('\nCompiling %s ... (this takes 5-15 minutes)\n\n', app_name);

% Build extra-files arg list with -a flags
add_files_args = {};
for i = 1:numel(extra_files)
    add_files_args{end+1} = '-a'; %#ok<AGROW>
    add_files_args{end+1} = extra_files{i}; %#ok<AGROW>
end
% Bundle the model
add_files_args{end+1} = '-a';
add_files_args{end+1} = model_path;

mcc('-m', main_file, ...
    '-o', app_name, ...
    '-d', output_dir, ...
    add_files_args{:}, ...
    '-v');   % verbose

fprintf('\nDone! Output in: %s\n', output_dir);
fprintf('Distribute the entire folder to users.\n');
fprintf('Users need MATLAB Runtime R2025b (one-time install): https://www.mathworks.com/products/compiler/matlab-runtime.html\n');
end