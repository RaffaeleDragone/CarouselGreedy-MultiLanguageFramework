classdef TestCarouselGreedy < matlab.unittest.TestCase
    %TESTCAROUSELGREEDY  Basic smoke test for carouselgreedy.CarouselGreedy

    methods (Test)
        function testMinimizeBasic(tc)
            % Setup candidati
            candidates = num2cell(1:10);

            % Feasibility: stop quando >=4 elementi
            testFeasibility = @(obj,sol) numel(sol) >= 4;

            % Greedy score: casuale
            greedyFunction  = @(obj,sol,cand) rand;

            cg = carouselgreedy.CarouselGreedy( ...
                testFeasibility, greedyFunction, candidates, ...
                'Alpha', 5, 'Beta', 0.3, 'Seed', 1, 'RandomTieBreak', true);

            sol = cg.minimize();

            % Verifica base: deve avere >=4 elementi
            tc.verifyGreaterThanOrEqual(numel(sol), 4);
            % Verifica che gli elementi provengano dai candidati
            tc.verifyTrue(all(ismember([sol{:}], [candidates{:}])));
        end
    end
end