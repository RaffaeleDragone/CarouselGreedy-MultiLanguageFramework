function main(instancesDir, outputPath, averagesOutputPath, alpha, beta, seed, feasibilityAware)
%MAIN Run Carousel Greedy on all Group II small MLST instances.
%
%   MAIN() finds every .mlst file in instances/group_II/small and writes a
%   detailed CSV plus a CSV containing one aggregate row per configuration.
%
%   Optional arguments override the instance directory, output paths and
%   algorithm parameters. Defaults: alpha=50, beta=0.10, seed=42,
%   feasibilityAware=true.

thisFile = mfilename('fullpath');
exampleDir = fileparts(thisFile);
repoRoot = fileparts(fileparts(exampleDir));
srcPath = fullfile(repoRoot, 'src');

if ~exist(fullfile(srcPath, '+carouselgreedy', 'CarouselGreedy.m'), 'file')
    error('CarouselGreedy not found at: %s', srcPath);
end
addpath(srcPath);

if nargin < 1 || isempty(instancesDir)
    instancesDir = fullfile(repoRoot, 'instances', 'group_II', 'small');
end
if nargin < 2 || isempty(outputPath)
    outputPath = fullfile(exampleDir, 'mlst_group_II_small_results.csv');
end
if nargin < 3 || isempty(averagesOutputPath)
    averagesOutputPath = fullfile(exampleDir, 'mlst_group_II_small_averages.csv');
end
if nargin < 4 || isempty(alpha), alpha = 50; end
if nargin < 5 || isempty(beta), beta = 0.10; end
if nargin < 6 || isempty(seed), seed = 42; end
if nargin < 7 || isempty(feasibilityAware), feasibilityAware = true; end

validateattributes(alpha, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(beta, {'numeric'}, {'scalar', '>=', 0, '<=', 1});
validateattributes(seed, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
validateattributes(feasibilityAware, {'logical'}, {'scalar'});

files = dir(fullfile(instancesDir, '*.mlst'));
if isempty(files)
    error('No .mlst instances found in: %s', instancesDir);
end
[~, order] = sort({files.name});
files = files(order);

ensureParentDirectory(outputPath);
ensureParentDirectory(averagesOutputPath);
results = emptyResultsTable();

for index = 1:numel(files)
    instancePath = fullfile(files(index).folder, files(index).name);
    result = solveInstance(readMLST(instancePath), alpha, beta, seed, feasibilityAware);
    results = [results; struct2table(result)]; %#ok<AGROW>

    % Incremental write: completed rows survive an interrupted batch.
    writetable(results, outputPath);
    fprintf(['[%03d/%03d] %s: greedy=%d cg=%d best=%d ' ...
             'time=%.6fs\n'], index, numel(files), result.instance, ...
             result.greedy_value, result.cg_value, result.best_value, ...
             result.elapsed_seconds);
end

averages = aggregateResults(results);
writetable(averages, averagesOutputPath);
fprintf('Results written to %s\n', outputPath);
fprintf('Averages written to %s\n', averagesOutputPath);
end


function result = solveInstance(instance, alpha, beta, seed, feasibilityAware)
%SOLVEINSTANCE Configure the MLST callbacks and run the library.

previousSolution = [];
componentIds = 1:instance.nodeCount;
componentCount = instance.nodeCount;

    function updateState(solution)
        solution = double(solution(:).');
        if isequal(solution, previousSolution)
            return;
        end

        canAppend = numel(solution) == numel(previousSolution) + 1 && ...
            isequal(solution(1:end-1), previousSolution);
        if canAppend
            [componentIds, componentCount] = addLabel( ...
                componentIds, componentCount, instance, solution(end));
        else
            componentIds = 1:instance.nodeCount;
            componentCount = instance.nodeCount;
            for label = solution
                [componentIds, componentCount] = addLabel( ...
                    componentIds, componentCount, instance, label);
            end
        end
        previousSolution = solution;
    end

    function feasible = mlstFeasibility(~, solution)
        updateState(solution);
        feasible = componentCount == 1;
    end

    function score = mlstGreedy(~, solution, candidate)
        updateState(solution);
        score = marginalComponentReduction( ...
            componentIds, componentCount, instance, candidate);
    end

cg = carouselgreedy.CarouselGreedy( ...
    @mlstFeasibility, @mlstGreedy, instance.labels, ...
    'Data', instance, 'Alpha', alpha, 'Beta', beta, ...
    'RandomTieBreak', true, 'FeasibilityAware', feasibilityAware, 'Seed', seed);

timer = tic;
bestSolution = cg.minimize(alpha, beta);
elapsed = toc(timer);
greedySolution = double(cg.GreedySolution(:).');
cgSolution = double(cg.CGSolution(:).');
bestSolution = double(bestSolution(:).');

result = struct( ...
    'instance', string(instance.name), ...
    'nodes', instance.nodeCount, ...
    'edges', instance.edgeCount, ...
    'labels', numel(instance.labels), ...
    'optimum', instance.optimum, ...
    'alpha', alpha, ...
    'beta', beta, ...
    'seed', seed, ...
    'feasibility_aware', feasibilityAware, ...
    'greedy_value', numel(greedySolution), ...
    'cg_value', numel(cgSolution), ...
    'best_value', numel(bestSolution), ...
    'improvement', numel(greedySolution) - numel(bestSolution), ...
    'elapsed_seconds', elapsed, ...
    'greedy_feasible', checkConnected(instance, greedySolution), ...
    'cg_feasible', checkConnected(instance, cgSolution), ...
    'best_labels', strjoin(string(bestSolution), ' '));
end


function instance = readMLST(path)
%READMLST Read a zero-based Group II .mlst instance.

fileId = fopen(path, 'r');
if fileId == -1, error('Cannot open %s', path); end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>

header = fscanf(fileId, '%d', 3);
if numel(header) ~= 3
    error('Invalid MLST header in %s', path);
end
edgeData = fscanf(fileId, '%d', [3, Inf]).';
nodeCount = header(1);
declaredEdgeCount = header(2);
if size(edgeData, 1) ~= declaredEdgeCount
    error('%s declares %d edges but contains %d', ...
        path, declaredEdgeCount, size(edgeData, 1));
end
if any(edgeData(:, 1:2) < 0, 'all') || ...
        any(edgeData(:, 1:2) >= nodeCount, 'all')
    error('Node outside the valid range in %s', path);
end

% Vertices are zero-based in the file and one-based inside MATLAB.
edgeData(:, 1:2) = edgeData(:, 1:2) + 1;
labels = unique(edgeData(:, 3), 'sorted').';
maxLabel = max(labels);
edgesByLabel = cell(1, maxLabel + 1);
for label = labels
    edgesByLabel{label + 1} = edgeData(edgeData(:, 3) == label, 1:2);
end

[~, name, extension] = fileparts(path);
nameFields = split(string(name), '_');
if numel(nameFields) < 4
    error('Cannot extract optimum from instance name: %s%s', name, extension);
end
optimum = str2double(nameFields(4));
if isnan(optimum)
    error('Invalid optimum in instance name: %s%s', name, extension);
end

instance = struct( ...
    'name', [name extension], ...
    'nodeCount', nodeCount, ...
    'edgeCount', size(edgeData, 1), ...
    'optimum', optimum, ...
    'labels', labels, ...
    'edgesByLabel', {edgesByLabel});

if ~checkConnected(instance, labels)
    error('The graph is not connected: %s', path);
end
end


function [newIds, newCount] = addLabel(componentIds, componentCount, instance, label)
%ADDLABEL Merge current components joined by the candidate label.

edges = instance.edgesByLabel{label + 1};
parent = 1:componentCount;
merges = 0;

for edgeIndex = 1:size(edges, 1)
    rootFirst = componentIds(edges(edgeIndex, 1));
    while parent(rootFirst) ~= rootFirst
        rootFirst = parent(rootFirst);
    end

    rootSecond = componentIds(edges(edgeIndex, 2));
    while parent(rootSecond) ~= rootSecond
        rootSecond = parent(rootSecond);
    end

    if rootFirst ~= rootSecond
        parent(rootSecond) = rootFirst;
        merges = merges + 1;
    end
end

if merges == 0
    newIds = componentIds;
    newCount = componentCount;
    return;
end

roots = parent;
for component = 1:componentCount
    root = component;
    while parent(root) ~= root
        root = parent(root);
    end
    roots(component) = root;
end
uniqueRoots = unique(roots, 'stable');
[~, compactIds] = ismember(roots, uniqueRoots);
newIds = compactIds(componentIds);
newCount = componentCount - merges;
end


function merges = marginalComponentReduction(componentIds, componentCount, instance, label)
%MARGINALCOMPONENTREDUCTION Count merges without rebuilding component IDs.

if componentCount <= 1
    merges = 0;
    return;
end

edges = instance.edgesByLabel{label + 1};
parent = 1:componentCount;
merges = 0;

for edgeIndex = 1:size(edges, 1)
    rootFirst = componentIds(edges(edgeIndex, 1));
    while parent(rootFirst) ~= rootFirst
        rootFirst = parent(rootFirst);
    end

    rootSecond = componentIds(edges(edgeIndex, 2));
    while parent(rootSecond) ~= rootSecond
        rootSecond = parent(rootSecond);
    end

    if rootFirst ~= rootSecond
        parent(rootSecond) = rootFirst;
        merges = merges + 1;
    end
end
end


function connected = checkConnected(instance, solution)
componentIds = 1:instance.nodeCount;
componentCount = instance.nodeCount;
for label = solution
    [componentIds, componentCount] = addLabel( ...
        componentIds, componentCount, instance, label);
end
connected = componentCount == 1;
end


function averages = aggregateResults(results)
groupColumns = {'nodes', 'edges', 'labels', 'optimum'};
groups = unique(results(:, groupColumns), 'rows', 'sorted');
count = height(groups);

avgCgObjective = zeros(count, 1);
avgBestObjective = zeros(count, 1);
avgTime = zeros(count, 1);
numOptimal = zeros(count, 1);
avgGap = zeros(count, 1);
instances = zeros(count, 1);

for index = 1:count
    selected = results.nodes == groups.nodes(index) & ...
        results.edges == groups.edges(index) & ...
        results.labels == groups.labels(index) & ...
        results.optimum == groups.optimum(index);
    cgObjective = results.cg_value(selected);
    bestObjective = results.best_value(selected);
    avgCgObjective(index) = round(mean(cgObjective), 1);
    avgBestObjective(index) = round(mean(bestObjective), 1);
    avgTime(index) = round(mean(results.elapsed_seconds(selected)), 6);
    numOptimal(index) = sum(bestObjective == groups.optimum(index));
    avgGap(index) = round( ...
        100 * (mean(bestObjective) - groups.optimum(index)) / groups.optimum(index), 1);
    instances(index) = sum(selected);
end

averages = [groups, table(avgCgObjective, avgBestObjective, avgTime, numOptimal, avgGap, instances, ...
    'VariableNames', {'avg_cg_objective', 'avg_best_objective', 'avg_time_seconds', ...
    'num_optimal', 'avg_gap_percent', 'instances'})];
end


function results = emptyResultsTable()
results = table( ...
    strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), false(0, 1), ...
    strings(0, 1), ...
    'VariableNames', {'instance', 'nodes', 'edges', 'labels', 'optimum', ...
    'alpha', 'beta', 'seed', 'feasibility_aware', 'greedy_value', 'cg_value', 'best_value', ...
    'improvement', 'elapsed_seconds', 'greedy_feasible', 'cg_feasible', ...
    'best_labels'});
end


function ensureParentDirectory(path)
parent = fileparts(path);
if ~isempty(parent) && ~exist(parent, 'dir')
    mkdir(parent);
end
end
