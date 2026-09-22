function batch_analyze_tree(root_folder, varargin)
% BATCH_ANALYZE_TREE
% Recursively walk root_folder, find every condition (a folder that holds
% the scan subfolders), and run analyze_stimulation_run on each one.
%
% Built for unattended overnight runs:
%   - one bad condition cannot kill the batch (per-condition try/catch)
%   - conditions already analyzed are skipped on re-run ('Redo' to force)
%   - aborts early on 3 identical failures in a row (systemic problem, e.g.
%     wrong model path or dead GPU - don't waste the whole night failing)
%   - 'DryRun' lists what it WOULD do (process vs skip) without running,
%     so you can verify the detection logic in seconds.
%
% A "condition" = a folder that directly contains >=1 subfolder whose name
% ends in _N or _N.ext (N = integer) AND that subfolder actually holds
% image frames. The image check matters: protocol folders like 'P1211_23'
% also end in _<number>, so a name match alone would mis-flag the subject
% level as a condition. Requiring real frames inside disambiguates.
%
% "Done" (skippable) = <condition>_analysis\timeseries.csv exists - NOT
% merely the _analysis folder, so interrupted/partial ones get redone.
%
% Usage:
%   batch_analyze_tree('D:\OCT_Run', 'DryRun', true)  % list the plan only
%   batch_analyze_tree('D:\OCT_Run')                  % live run
%   batch_analyze_tree('D:\OCT_Run', 'PxPerMm', 200)
%   batch_analyze_tree('D:\OCT_Run', 'Redo', true)    % re-do finished ones

p = inputParser;
addParameter(p, 'PxPerMm', 200);
addParameter(p, 'Redo', false);
addParameter(p, 'DryRun', false);
addParameter(p, 'AnalyzeArgs', {});
parse(p, varargin{:});
opt = p.Results;

if ~isfolder(root_folder)
    error('Root folder not found: %s', root_folder);
end
root_folder = regexprep(root_folder, '[\\/]+$', '');

out_name = 'batch_summary.csv';
if opt.DryRun; out_name = 'batch_plan.csv'; end
fid = fopen(fullfile(root_folder, 'batch_log.txt'), 'a');
logf(fid, '==== batch_analyze_tree %s%s ====', datestr(now), tern(opt.DryRun,'  [DRY RUN]',''));
logf(fid, 'Root: %s', root_folder);

% --- 1. Find all conditions -------------------------------------------
conditions = find_conditions(root_folder, {});
logf(fid, 'Found %d condition folder(s).', numel(conditions));
if isempty(conditions)
    logf(fid, 'Nothing found. Check that scan folders end in _N and hold images.');
    fclose(fid); return;
end

% --- 2. Process (or, in dry run, classify) each -----------------------
n = numel(conditions);
status  = strings(n,1);  nframes = nan(n,1);
seconds = nan(n,1);      errmsg  = strings(n,1);
consec_fail = 0;  prev_err = "";

for i = 1:n
    cdir = conditions{i};

    % Determine subject directory and output analysis directory (Subject level: 4.2.1)
    [parent1, name1] = fileparts(cdir);
    if ~isempty(parent1) && ~strcmp(parent1, cdir)
        subj_dir = parent1;
        proto_name = name1;
    else
        subj_dir = cdir;
        proto_name = '';
    end
    [subj_parent, subj_name] = fileparts(subj_dir);
    subj_analysis_dir = fullfile(subj_parent, [subj_name, '_analysis']);

    % Check if multiple conditions share the same subject folder
    same_subj_count = sum(cellfun(@(c) strcmp(fileparts(c), subj_dir), conditions));
    if same_subj_count > 1 && ~isempty(proto_name)
        file_prefix = proto_name;
        done_csv = fullfile(subj_analysis_dir, [file_prefix, '_timeseries.csv']);
    else
        file_prefix = '';
        done_csv = fullfile(subj_analysis_dir, 'timeseries.csv');
    end

    legacy_done_csv = fullfile([cdir '_analysis'], 'timeseries.csv');
    already  = (exist(done_csv, 'file') > 0) || (exist(legacy_done_csv, 'file') > 0);

    if opt.DryRun
        status(i) = tern(already, "would skip(done)", "would PROCESS");
        logf(fid, '[%d/%d] %-16s %s -> %s', i, n, status(i), cdir, subj_analysis_dir);
        continue;
    end

    if ~opt.Redo && already
        status(i) = "skipped(done)";
        consec_fail = 0;  prev_err = "";
        logf(fid, '[%d/%d] SKIP done: %s (%s)', i, n, cdir, subj_analysis_dir);
        write_summary(root_folder, out_name, conditions, status, nframes, seconds, errmsg);
        continue;
    end

    logf(fid, '[%d/%d] START: %s -> %s', i, n, cdir, subj_analysis_dir);
    t0 = tic;
    try
        analyze_stimulation_run(cdir, 'PxPerMm', opt.PxPerMm, ...
            'OutputDir', subj_analysis_dir, ...
            'FilePrefix', file_prefix, ...
            opt.AnalyzeArgs{:});
        seconds(i) = toc(t0);
        nframes(i) = count_csv_rows(done_csv);
        status(i)  = "ok";
        consec_fail = 0;  prev_err = "";
        logf(fid, '[%d/%d] OK  %.1f min  %d frames: %s -> %s', ...
            i, n, seconds(i)/60, nframes(i), cdir, subj_analysis_dir);
    catch ME
        seconds(i) = toc(t0);
        status(i)  = "failed";
        errmsg(i)  = string(ME.message);
        if strcmp(errmsg(i), prev_err); consec_fail = consec_fail + 1;
        else;                           consec_fail = 1; end
        prev_err = errmsg(i);
        logf(fid, '[%d/%d] FAILED (%s): %s', i, n, ME.message, cdir);
    end
    write_summary(root_folder, out_name, conditions, status, nframes, seconds, errmsg);

    if consec_fail >= 3
        logf(fid, 'ABORT: 3 identical failures in a row - likely systemic (model path? GPU?). Stopping.');
        break;
    end
end

if opt.DryRun
    logf(fid, 'PLAN: %d would process, %d already done.', ...
        sum(status=="would PROCESS"), sum(status=="would skip(done)"));
else
    logf(fid, 'DONE.  ok=%d  failed=%d  skipped=%d', ...
        sum(status=="ok"), sum(status=="failed"), sum(startsWith(status,"skipped")));
end
write_summary(root_folder, out_name, conditions, status, nframes, seconds, errmsg);
fclose(fid);
fprintf('\n%s written: %s\n', tern(opt.DryRun,'Plan','Summary'), ...
    fullfile(root_folder, out_name));
end

% =====================================================================
function acc = find_conditions(folder, acc)
if is_condition_folder(folder)
    acc{end+1} = folder;          % this IS a condition; stop descending
    return;
end
d = dir(folder);
d = d([d.isdir] & ~ismember({d.name}, {'.','..'}));
d = d(~endsWith({d.name}, '_out',      'IgnoreCase', true));
d = d(~endsWith({d.name}, '_analysis', 'IgnoreCase', true));
for i = 1:numel(d)
    acc = find_conditions(fullfile(folder, d(i).name), acc);
end
end

% =====================================================================
function tf = is_condition_folder(folder)
d = dir(folder);
d = d([d.isdir] & ~ismember({d.name}, {'.','..'}));
d = d(~endsWith({d.name}, '_out', 'IgnoreCase', true));
tf = false;
for i = 1:numel(d)
    if ~isempty(regexp(d(i).name, '_(\d+)(?:\.[^.]+)?$', 'once')) ...
            && folder_has_images(fullfile(folder, d(i).name))
        tf = true; return;
    end
end
end

% =====================================================================
function tf = folder_has_images(folder)
exts = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff','*.bin'};
tf = false;
for k = 1:numel(exts)
    if ~isempty(dir(fullfile(folder, exts{k}))); tf = true; return; end
end
end

% =====================================================================
function r = count_csv_rows(f)
r = NaN;
fid = fopen(f); if fid < 0; return; end
r = 0; fgetl(fid);                       % skip header
while ~feof(fid)
    ln = fgetl(fid);
    if ischar(ln) && ~isempty(ln); r = r + 1; end
end
fclose(fid);
end

% =====================================================================
function write_summary(root, fname, conditions, status, nframes, seconds, errmsg)
T = table(string(conditions(:)), status, nframes, seconds, errmsg, ...
    'VariableNames', {'condition','status','n_frames','seconds','error'});
try
    writetable(T, fullfile(root, fname));
catch
    % csv may be open in Excel - skip this write, next one will catch up
end
end

% =====================================================================
function out = tern(cond, a, b)
if cond; out = a; else; out = b; end
end

% =====================================================================
function logf(fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
fprintf('%s\n', msg);
if fid > 0; fprintf(fid, '%s\n', msg); end
end