function simple_mvc()
%SIMPLE_MVC Simple example of Minimum Vertex Cover using CarouselGreedy.
%
% This version uses a straightforward implementation:
% - The greedy function computes the degree of each candidate node
%   considering only uncovered edges.
% - The feasibility check tests whether all edges are covered.
%
% No incremental data structures are updated between iterations.

% --- Auto-setup: ensure CarouselGreedy is on MATLAB path ---
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(fileparts(thisFile)));  % mvc -> examples -> root
srcPath = fullfile(repoRoot, 'src');

if exist(fullfile(srcPath, '+carouselgreedy', 'CarouselGreedy.m'), 'file')
    addpath(genpath(srcPath));
    fprintf('[CarouselGreedy] Path added: %s\n', srcPath);
else
    error('CarouselGreedy not found at: %s', srcPath);
end

% --- Load a small test instance ---
filePath = 'examples/mvc/data/100_nodes.mis';
[A, n] = read_instance(filePath);
A = logical(A);

alpha = 10;
beta = 0.1;
seed = 1;
rng(seed);

% --- Define callbacks ---
    function feasible = myFeas(~, sol)
        % Check if all edges are covered by the current solution
        covered = false(size(A));
        covered(sol, :) = true;
        covered(:, sol) = true;
        uncovered = A & ~covered;
        feasible = ~any(uncovered(:));
    end

    function score = myGreedy(~, sol, cand)
        % Compute residual degree ignoring nodes already in solution
        mask = true(1, n);
        mask(sol) = false;
        deg = sum(A(mask, :), 1);   % degrees of all nodes
        score = deg(cand);          % greedy score = residual degree
    end

    
% --- Run CarouselGreedy ---
cg = carouselgreedy.CarouselGreedy(@myFeas, @myGreedy, 1:n, ...
        'Data', struct('A', A), ...
        'Alpha', alpha, 'Beta', beta, ...
        'RandomTieBreak', true, 'Seed', seed);

tic;
bestSol = cg.minimize();
elapsed = toc;

% --- Check final solution ---
valid = myFeas(cg, bestSol);

% --- Display results ---
fprintf('\n--- Instance file: %s ---\n', filePath);
fprintf('Greedy size           : %d\n', numel(cg.GreedySolution));
fprintf('Carousel‑Greedy size  : %d\n', numel(cg.CGSolution));
fprintf('Cover valid?          : %d\n', valid);
fprintf('Elapsed time          : %.6f seconds\n', elapsed);

end


%% --- Helper function to load instance ---
function [M, nNodes] = read_instance(fname)
    fid = fopen(fname,'r');  if fid==-1, error('Cannot open %s',fname); end
    cleanup = onCleanup(@() fclose(fid));
    nNodes = 0; edges = [];
    line = fgetl(fid);
    while ischar(line)
        if startsWith(line,'p')
            tk = strsplit(strtrim(line));
            nNodes = str2double(tk{3});
        elseif startsWith(line,'e')
            tk = strsplit(strtrim(line));
            edges(end+1,:) = [str2double(tk{2}) str2double(tk{3})]; %#ok<AGROW>
        end
        line = fgetl(fid);
    end
    if nNodes==0, error('Instance file lacks "p edge" header.'); end
    M = sparse(edges(:,1), edges(:,2), true, nNodes, nNodes);
    M = M | M.';
    M = logical(full(M));
end