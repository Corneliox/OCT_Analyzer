function compile_oct_app_installer()
% COMPILE_OCT_APP_INSTALLER
% Produces a Windows installer .exe that auto-downloads MATLAB Runtime
% if the user doesn't have it.
%
% Output:
%   OCTAnalyzer_installer\installer\OCTAnalyzerInstaller.exe (or _web.exe)
%
% User experience:
%   1. Download the installer .exe
%   2. Double-click it
%   3. Auto-installs MCR if missing (~3 GB download, one-time)
%   4. Installs the app + Start Menu shortcut
%   5. User runs "OCT Skin Layer Analyzer" from Start Menu

% -------- Config -------------------------------------------------------
app_name   = 'OCTAnalyzer_Optimized';
main_file  = 'OCTAnalyzerApp.m';
output_dir = fullfile(fileparts(mfilename('fullpath')), 'dist');

extra_files = {
    'batch_analyze_tree.m'
    'analyze_stimulation_run.m'
    'segment_new_images.m'
    'extract_boundaries_dp.m'
    'check_segmentation.m'
    'preprocess_image_only.m'
};

model_search_path = fullfile(fileparts(mfilename('fullpath')), 'trained_variantA');
% -----------------------------------------------------------------------

if license('test', 'Compiler') == 0
    error('MATLAB Compiler license not found.');
end

mdl = dir(fullfile(model_search_path, 'unet_variantA_*.mat'));
if isempty(mdl)
    error('No trained model (unet_variantA_*.mat) found in %s', model_search_path);
end
[~, ix] = max([mdl.datenum]);
model_path = fullfile(mdl(ix).folder, mdl(ix).name);
fprintf('Bundling model: %s\n', model_path);

all_files = [{main_file}, extra_files(:)'];
for i = 1:numel(all_files)
    if ~exist(all_files{i}, 'file')
        error('Required file missing: %s', all_files{i});
    end
end

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('\nBuilding standalone app (5-15 minutes)...\n\n');

opts = compiler.build.StandaloneApplicationOptions(main_file, ...
    'OutputDir', output_dir, ...
    'ExecutableName', app_name, ...
    'ExecutableVersion', '2.2.0', ...
    'AdditionalFiles', [extra_files(:); {model_path}], ...
    'Verbose', 'on');

results = compiler.build.standaloneApplication(opts);

fprintf('\nBuilding installer package...\n');
if ispc
    installer_name = [app_name 'Installer_Win'];
elseif ismac
    installer_name = [app_name 'Installer_Mac'];
else
    installer_name = [app_name 'Installer_Linux'];
end

compiler.package.installer(results, ...
    'InstallerName', installer_name, ...
    'ApplicationName', 'OCT Skin Layer Analyzer', ...
    'AuthorCompany', 'Your Lab Name', ...
    'AuthorName', 'Your Name', ...
    'Description', 'Automated segmentation and analysis of skin OCT B-scan images', ...
    'Version', '2.2.0', ...
    'OutputDir', output_dir, ...
    'RuntimeDelivery', 'web');

fprintf('\nDone! Standalone app & Installer ready in: %s\n', output_dir);
fprintf('1. Standalone executable: %s.exe\n', fullfile(output_dir, app_name));
fprintf('2. Installer package: %s.exe\n', fullfile(output_dir, installer_name));
end