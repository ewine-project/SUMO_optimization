%> @file "SOSBO.m"
%> @authors: SUMO Lab Team
%> @version 7.0.3 ($Revision: 7155 $)
%> @date $LastChangedDate: 2011-06-02 10:46:47 +0200 (Thu, 02 Jun 2011) $
%> @date Copyright 2006-2010
%>
%> This file is part of the Surrogate Modeling Toolbox ("SUMO Toolbox")
%> and you can redistribute it and/or modify it under the terms of the
%> GNU Affero General Public License version 3 as published by the
%> Free Software Foundation.  With the additional provision that a commercial
%> license must be purchased if the SUMO Toolbox is used, modified, or extended
%> in a commercial setting. For details see the included LICENSE.txt file.
%> When referring to the SUMO Toolbox please make reference to the corresponding
%> publication:
%>   - A Surrogate Modeling and Adaptive Sampling Toolbox for Computer Based Design
%>   D. Gorissen, K. Crombecq, I. Couckuyt, T. Dhaene, P. Demeester,
%>   Journal of Machine Learning Research,
%>   Vol. 11, pp. 2051-2055, July 2010. 
%>
%> Contact : sumo@sumo.intec.ugent.be - http://sumo.intec.ugent.be
%> Signature
%>	 SOSBO(samplesValuesFile, outDimIdx)
%
% ======================================================================
%> @brief Single Objective Surrogate Based Optimizer (SOSBO)
% ======================================================================
% Modified by : Michael Mehari
% Email: mmehari@intec.ugent.be
function newSample = SOSBO(samplesValuesPath, outDimIdx)

% import samples and values data
samplesValueData = importdata(samplesValuesPath);
samplesValues = samplesValueData.data;

% bounds of the input variables
bounds = eval(samplesValueData.textdata{1});

inDimIdx =  (1 : size(bounds,2));

numOfItemsPerSamples = (bounds(2,:) - bounds(1,:))./bounds(3,:) + 1; % size of input variables

transl = (bounds(2,:) + bounds(1,:))/2.0;
scale = (bounds(2,:) - bounds(1,:))/2.0;
[inFunc outFunc] = calculateTransformationFunctions( [transl; scale] );

samples = inFunc(samplesValues(:,inDimIdx));          % convert samples to simulator space
values = samplesValues(:,outDimIdx);

inDim = size(samples,2); % number of input variables

% general options
distanceThreshold = 2.*eps;

% setup kriging model options
type = 'Kriging';
opts = feval([type '.getDefaultOptions'] );
opts.type = type;

theta0 = repmat(0.25,1,inDim);

lb = repmat(-2,1,inDim);
ub = repmat(2,1,inDim);

% CHANGEME: correlation function to use
%bf = BasisFunction( 'corrgauss', inDim, lb, ub, {'log'});
%bf = BasisFunction( 'correxp', inDim, lb, ub, {'log'});
bf = BasisFunction( 'corrmatern32', inDim, lb, ub, {'log'});

opts.hpOptimizer = SQPLabOptimizer( inDim, 1 );

%% select optimizer to use
optimizer = DiscreteOptimizer(inDim, 1, numOfItemsPerSamples);
optimizer = optimizer.setBounds(-ones(1,inDim), ones(1,inDim));

%% candidateRankers to use
rankers = {expectedImprovement(inDim, 'none', [], []) maxvar(inDim, 'none') };

%% main loop
nrSamples = prod(numOfItemsPerSamples);
    
% build and fit Kriging object
k = KrigingModel( opts, theta0, 'regpoly0', bf, 'useLikelihood' );
k = k.constructInModelSpace( samples, values );

% optimize it
state.lastModels{1}{1} = k;
state.samples = samples;
state.values = values;

for i=1:length(rankers)

    rankers{i} = rankers{i}.initNewSamples(state);

    initialPopulation = rand(nrSamples, inDim) .* 2 - 1;

    foundvalues = rankers{i}.score(initialPopulation, state);
    [~, idx] = sort( foundvalues, 1, 'descend' );

    %% optimize best candidate

    % set initial population
    maxPopSize = optimizer.getPopulationSize();
    initialPopulation = initialPopulation(idx(1:maxPopSize,:),:);
    
    optimizer = optimizer.setInitialPopulation(initialPopulation);

    % give the state to the optimizer - might contain useful info such as # samples
    optimizer = optimizer.setState(state);

    optimFunc = @(x) rankers{i}.scoreMinimize(x, state);
    [~, xmin, fmin] = optimizer.optimize(optimFunc);

    dups = buildDistanceMatrix( xmin, samples, 1 );
    index = find(all(dups > distanceThreshold, 2));

    xmin = xmin(index,:);
    fmin = fmin(index,:);

    if ~isempty( xmin )
        break;
    end

end

if isempty( xmin )
    xmin = 2.*(rand(1,inDim) - 0.5);
end

%% evaluate new samples and add to set    
newSample = outFunc(xmin(1,:));         % convert the new sample back to model space

format longG;

end
