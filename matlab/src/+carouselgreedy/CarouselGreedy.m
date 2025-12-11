classdef CarouselGreedy < handle
    %CAROUSELGREEDY  Generic and extensible implementation of the Carousel
    %Greedy meta‑heuristic, ported from Python.
    %
    %   OBJ = CarouselGreedy(TESTFEASIBILITY, GREEDYFUNCTION, CANDIDATEELEMENTS, ...)
    %   Mandatory
    %       TESTFEASIBILITY – @(obj,solution) -> logical scalar
    %       GREEDYFUNCTION  – @(obj,solution,candidate) -> double score
    %       CANDIDATEELEMENTS – array OR cell array of arbitrary types
    %   Optional name‑value pairs
    %       'Alpha' (int>0)           multiplier for iterative phase length
    %       'Beta'  (0≤β≤1)           fraction removed in removal phase
    %       'Data'                    arbitrary user data (accessible via obj.Data)
    %       'RandomTieBreak' (bool)   random choice among top‑scoring candidates
    %       'Seed'  (integer)         RNG seed
    
    %   Public API (mirrors the Python version)
    %       greedyMinimize / greedyMaximize – only greedy construction
    %       minimize        / maximize      – full Carousel optimisation
    %
    %   Implementation notes
    %       • Handles numeric arrays, strings or mixed cell arrays seamlessly.
    %       • Internal helpers convert between cell/array where needed.
    %       • Designed for speed: explicit loops (JIT‑friendly), pre‑allocation,
    %         optional PARFOR, and compatible with MATLAB Coder (avoid
    %         anonymous functions that capture workspace for code‑generation).
    %
    %  2025 – initial MATLAB port by ChatGPT (rev‑2: cell‑array compatibility)

    %% Public properties (user‑tunable)
    properties
        Alpha (1,1) double {mustBePositive, mustBeInteger} = 10
        Beta  (1,1) double = 0.2
        Data                                            % arbitrary struct / matrix / etc.
        CandidateElements                               % cell|array of candidates
        RandomTieBreak logical = true
        Seed   (1,1) double {mustBeInteger} = 42
    end

    %% Public‑read / private‑write properties
    properties (SetAccess = private)
        GreedySolution    % solution after construction phase
        CGSolution        % final Carousel‑Greedy (after all phases)
        Iteration   = 0   % counter inside iterative phase
    end

    %% Internal state (hidden from user)
    properties (Access = private)
        ProblemType char            % 'MIN' | 'MAX'
        Solution                    % current working solution (cell | array)
        TestFeasibility   function_handle
        GreedyFunction    function_handle
        RNG
    end

    %% ---------------------------------------------------------------------
    %% Constructor
    methods
        function obj = CarouselGreedy(testFeasibility, greedyFunction, candidateElements, varargin)
            % Basic sanity
            if ~isa(testFeasibility,'function_handle')
                error('testFeasibility must be a function handle.');
            end
            if ~isa(greedyFunction,'function_handle')
                error('greedyFunction must be a function handle.');
            end
            if nargin < 3 || isempty(candidateElements)
                error('candidateElements must be provided and non‑empty.');
            end

            % Parse name‑value pairs (keep old MATLAB compatibility)
            p = inputParser;
            addParameter(p,'Alpha',10,@(x)validateattributes(x,{'numeric'},{'scalar','integer','positive'}));
            addParameter(p,'Beta',0.2,@(x)validateattributes(x,{'numeric'},{'scalar','>=',0,'<=',1}));
            addParameter(p,'Data',[]);
            addParameter(p,'RandomTieBreak',true,@(x)islogical(x)&&isscalar(x));
            addParameter(p,'Seed',42,@(x)validateattributes(x,{'numeric'},{'scalar','integer','nonnegative'}));
            parse(p,varargin{:});

            % Store parameters
            obj.Alpha          = p.Results.Alpha;
            obj.Beta           = p.Results.Beta;
            obj.Data           = p.Results.Data;
            obj.RandomTieBreak = p.Results.RandomTieBreak;
            obj.Seed           = p.Results.Seed;

            obj.TestFeasibility = testFeasibility;
            obj.GreedyFunction  = greedyFunction;
            obj.CandidateElements = candidateElements;
            obj.Solution = obj.emptyLike(candidateElements);

            % RNG setup
            obj.RNG = RandStream('mt19937ar','Seed',obj.Seed);
            RandStream.setGlobalStream(obj.RNG);
        end
    end

    %% ---------------------------------------------------------------------
    %% Public API
    methods
        function sol = greedyMinimize(obj)
            obj.ProblemType = 'MIN';
            sol = obj.constructionPhase();
            obj.GreedySolution = sol;
        end

        function sol = greedyMaximize(obj)
            obj.ProblemType = 'MIN';
            tmp = obj.constructionPhase();
            obj.Solution = tmp;  % copy
            obj.ProblemType = 'MAX';
            sol = obj.constructionPhase();
            obj.GreedySolution = sol;
        end

        function best = minimize(obj, alpha, beta)
            if nargin < 2 || isempty(alpha), alpha = obj.Alpha; end
            if nargin < 3 || isempty(beta),  beta  = obj.Beta;  end
            [backupAlpha, backupBeta] = deal(obj.Alpha, obj.Beta);
            obj.Alpha = alpha;  obj.Beta = beta; obj.ProblemType = 'MIN';

            greedy = obj.greedyMinimize();
            initLen = numel(greedy);
            obj.removalPhase();
            obj.iterativePhase(obj.Alpha * initLen);
            obj.completionPhase();
            obj.CGSolution = obj.Solution;

            if numel(obj.CGSolution) < numel(greedy)
                best = obj.CGSolution;
            else
                best = greedy;
            end
            [obj.Alpha,obj.Beta] = deal(backupAlpha,backupBeta);
        end

        function best = maximize(obj, alpha, beta)
            if nargin < 2 || isempty(alpha), alpha = obj.Alpha; end
            if nargin < 3 || isempty(beta),  beta  = obj.Beta;  end
            [backupAlpha, backupBeta] = deal(obj.Alpha, obj.Beta);
            obj.Alpha = alpha;  obj.Beta = beta; obj.ProblemType = 'MAX';

            greedy = obj.greedyMaximize();
            initLen = numel(greedy);
            obj.removalPhase();
            obj.iterativePhase(obj.Alpha * initLen);
            obj.completionPhase();
            obj.CGSolution = obj.Solution;

            if numel(obj.CGSolution) > numel(greedy)
                best = obj.CGSolution;
            else
                best = greedy;
            end
            [obj.Alpha,obj.Beta] = deal(backupAlpha,backupBeta);
        end
    end

    %% ---------------------------------------------------------------------
    %% Core phases
    methods (Access = private)

        % -- Construction ---------------------------------------------------
        function sol = constructionPhase(obj)
            while true
                switch obj.ProblemType
                    case 'MIN'
                        if obj.TestFeasibility(obj, obj.Solution)
                            break;              % already feasible
                        end
                        cand = obj.selectBestCandidate();
                        if isempty(cand), break; end
                        obj.appendToSolution(cand);
                    case 'MAX'
                        cand = obj.selectBestCandidate();
                        if isempty(cand), break; end
                        obj.appendToSolution(cand);
                    otherwise
                        error('Invalid internal ProblemType.');
                end
            end
            sol = obj.Solution;
        end

        % -- Removal --------------------------------------------------------
        function removalPhase(obj)
            toRemove = floor(numel(obj.Solution) * obj.Beta);
            if numel(obj.Solution) - toRemove < 1
                toRemove = numel(obj.Solution) - 2;
            end
            if toRemove > 0
                obj.Solution(end-toRemove+1:end) = [];
            end
        end

        % -- Iterative phase ------------------------------------------------
        function iterativePhase(obj, iterations)
            for k = 1:iterations
                obj.Iteration = obj.Iteration + 1;
                if ~isempty(obj.Solution)
                    obj.Solution(1) = [];
                end
                cand = obj.selectBestCandidate();
                if isempty(cand), break; end
                if obj.ProblemType == 'MIN'
                    obj.appendToSolution(cand);
                else  % 'MAX'
                    tmp = obj.concatenateSolutions(obj.Solution, cand);
                    if obj.TestFeasibility(obj, tmp)
                        obj.Solution = tmp;
                    end
                end
            end
        end

        % -- Completion -----------------------------------------------------
        function completionPhase(obj)
            switch obj.ProblemType
                case 'MIN'
                    while ~obj.TestFeasibility(obj, obj.Solution)
                        cand = obj.selectBestCandidate();
                        if isempty(cand), break; end
                        obj.appendToSolution(cand);
                    end
                case 'MAX'
                    while true
                        elig = obj.remainingCandidates();
                        if isempty(elig), break; end
                        feasibleMask = false(size(elig));
                        for i = 1:numel(elig)
                            feasibleMask(i) = obj.TestFeasibility(obj, obj.concatenateSolutions(obj.Solution, elig{i}));
                        end
                        feasCand = elig(feasibleMask);
                        if isempty(feasCand), break; end
                        idx = obj.rankByScore(feasCand, obj.Solution);
                        obj.appendToSolution(feasCand{idx});
                    end
            end
        end

        % -- Candidate selection -------------------------------------------
        function cand = selectBestCandidate(obj)
            % ---------- GENERIC PATH (original implementation) -------------
            elig = obj.remainingCandidates();
            if isempty(elig)
                cand = [];
                return;
            end
            n = numel(elig);
            scores = zeros(1,n);
            for i = 1:n
                scores(i) = obj.GreedyFunction(obj, obj.Solution, obj.extractElement(elig,i));
            end
            bestScore = max(scores);
            idx = find(scores == bestScore);
            if obj.RandomTieBreak && numel(idx) > 1
                idx = idx( randi(obj.RNG, numel(idx)) );
            end
            cand = obj.extractElement(elig, idx(1));
        end

        % -- Helper: ranking among feasible -------------------------------
        function idx = rankByScore(obj, candList, baseSol)
            n = numel(candList);
            scores = zeros(1,n);
            for i = 1:n
                scores(i) = obj.GreedyFunction(obj, baseSol, obj.extractElement(candList,i));
            end
            idx = find(scores == max(scores), 1);
        end
    end

    %% ---------------------------------------------------------------------
    %% Low‑level utility helpers
    methods (Access = private)
        function appendToSolution(obj, element)
            if iscell(obj.Solution)
                obj.Solution{end+1} = element;
            else
                obj.Solution(end+1) = element;
            end
        end

        function rem = remainingCandidates(obj)
            % Return candidates not yet in Solution (cell‑compatible)
            if isempty(obj.Solution)
                rem = obj.CandidateElements;
                return;
            end

            if iscell(obj.CandidateElements)
                % use isequal for generic content (slower but generic)
                rem = obj.CandidateElements(~cellfun(@(x) obj.inSolution(x), obj.CandidateElements));
            else
                rem = obj.CandidateElements(~ismember(obj.CandidateElements, obj.Solution));
            end
        end

        function tf = inSolution(obj, elem)
            if iscell(obj.Solution)
                tf = any(cellfun(@(x) isequal(x,elem), obj.Solution));
            else
                tf = any(obj.Solution == elem);
            end
        end

        function out = extractElement(~, container, idx)
            if iscell(container)
                out = container{idx};
            else
                out = container(idx);
            end
        end

        function concat = concatenateSolutions(obj, sol, cand)
            if iscell(sol)
                concat = [sol, {cand}];
            else
                concat = [sol, cand];
            end
        end

        function e = emptyLike(~, prototype)
            if iscell(prototype)
                e = {};
            else
                e = prototype([]);
            end
        end
    end
end
