function enhanced_mvc()
%ENHANCED_MVC Solve the Minimum Vertex Cover problem using CarouselGreedy.
%
% This script demonstrates the use of the CarouselGreedy algorithm on a
% graph instance loaded from a file. It sets up the MATLAB path for the
% CarouselGreedy library, reads the instance, and runs the solver with
% custom feasibility and greedy scoring callbacks.
%
% Dependencies:
%   - CarouselGreedy library (src/+carouselgreedy/CarouselGreedy.m)
%
% Usage:
%   Run this script directly; it will load the instance, run the solver,
%   and print the results including solution sizes and elapsed time.

% --- Setup MATLAB path to include CarouselGreedy library ---
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(fileparts(thisFile)));  % Navigate up to repo root
srcPath = fullfile(repoRoot, 'src');

if exist(fullfile(srcPath, '+carouselgreedy', 'CarouselGreedy.m'), 'file')
    addpath(genpath(srcPath));
    fprintf('[CarouselGreedy] Path added: %s\n', srcPath);
else
    warning('CarouselGreedy not found at: %s', srcPath);
end

% --- Problem parameters and instance loading ---
filePath = 'examples/mvc/data/100_nodes.mis';  % Instance file path
alpha = 10;    % Algorithm parameter alpha
beta  = 0.1;  % Algorithm parameter beta
seed  = 1;    % Random seed for reproducibility

[A, n] = read_instance(filePath);  % Load adjacency matrix and number of nodes
rng(seed);                         % Set random seed

A_orig = logical(A);  % Immutable adjacency matrix for reference

%% --- Initialize lightweight state for incremental updates ---
% Create adjacency list representation for efficient neighbor access
adjList = cell(1,n);
[row,col] = find(triu(A_orig));  % Extract edges from upper triangle to avoid duplicates
for k = 1:numel(row)
    adjList{row(k)}(end+1) = col(k);
    adjList{col(k)}(end+1) = row(k);
end

deg     = full(sum(A_orig,2))';  % Degree of each vertex (number of uncovered edges)
inCover = false(1,n);             % Logical mask indicating vertices currently in the cover
prevSol = [];                    % Cache previous solution to avoid redundant state updates

%% --- Callback functions required by CarouselGreedy ---

    function feasible = myFeas(~, sol)
        % Check if the current solution covers all edges (feasibility)
        updateState(sol);
        feasible = max(deg) == 0;  % Feasible if no uncovered edges remain
    end

    function score = myGreedy(~, sol, cand)
        % Compute greedy score for candidate vertices based on uncovered edge degrees
        if ~isequal(sol, prevSol)
            updateState(sol);  % Update state only if solution changed
        end
        score = deg(cand);  % Score is number of uncovered edges incident to candidate
    end

    function updateState(sol)
        % Incrementally update degrees and cover mask based on solution changes
        if isequal(sol, prevSol), return; end

        solMask  = false(1,n); solMask(sol) = true;  % Current solution mask
        prevMask = inCover;                          % Previous cover mask

        removedMask  = prevMask & ~solMask;   % Vertices removed from cover
        insertedMask = solMask  & ~prevMask;  % Vertices added to cover

        % Increase degrees for edges uncovered by removed vertices
        for v = find(removedMask)
            for w = adjList{v}
                if ~solMask(w)
                    deg(v) = deg(v) + 1;
                    deg(w) = deg(w) + 1;
                end
            end
        end

        % Decrease degrees for edges covered by inserted vertices
        for v = find(insertedMask)
            for w = adjList{v}
                if ~solMask(w)
                    deg(w) = deg(w) - 1;
                end
            end
            deg(v) = 0;  % Vertex in cover covers all its edges
        end

        % Update state variables
        inCover = solMask;
        prevSol = sol;

        % Robust full recomputation of degrees to ensure consistency
        uncoveredMask = ~inCover;
        deg = zeros(1, n);
        for v = find(uncoveredMask)
            deg(v) = sum(uncoveredMask(adjList{v}));
        end
    end

%% --- Instantiate CarouselGreedy solver with callbacks and parameters ---
cg = carouselgreedy.CarouselGreedy(@myFeas, @myGreedy, 1:n, ...
                    'Data', struct('original_matrix', A_orig, 'n_nodes', n), ...
                    'Alpha', alpha, 'Beta', beta, ...
                    'RandomTieBreak', true, 'Seed', seed);

%% --- Execute solver and measure runtime ---
pause(0.01); % Short pause for system stability
tic;
bestSol = cg.minimize();
elapsed = toc;

%% --- Validate final solution feasibility ---
valid = myFeas(cg, bestSol);

%% --- Display results ---
fprintf('\n--- Instance file: %s ---\n', filePath);
fprintf('Greedy size           : %d\n', numel(cg.GreedySolution));
fprintf('Carousel‑Greedy size  : %d\n', numel(cg.CGSolution));
fprintf('Cover valid?          : %d\n', valid);
fprintf('Elapsed time          : %.6f seconds\n', elapsed);

%% --- Helper function to read graph instance from file ---
    function [M, nNodes] = read_instance(fname)
        % Reads a graph instance in DIMACS-like format and returns adjacency matrix.
        fid = fopen(fname,'r');  if fid==-1, error('Cannot open %s',fname); end
        cleanup = onCleanup(@() fclose(fid));
        nNodes = 0;  edges = [];
        line = fgetl(fid);
        while ischar(line)
            if startsWith(line,'p')
                tk = strsplit(strtrim(line));
                nNodes = str2double(tk{3});  % Number of vertices
            elseif startsWith(line,'e')
                tk = strsplit(strtrim(line));
                edges(end+1,:) = [str2double(tk{2}) str2double(tk{3})]; %#ok<AGROW>
            end
            line = fgetl(fid);
        end
        if nNodes==0, error('Instance file lacks "p edge" header.'); end
        M = sparse(edges(:,1), edges(:,2), true, nNodes, nNodes);
        M = M | M.';     % Make adjacency matrix symmetric (undirected graph)
        M = logical(full(M));
    end
end
