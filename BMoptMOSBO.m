%> @file "BMoptMOSBO.m"
%> @authors: SUMO Lab Team
%> @version x.x.x ($Revision: 7155 $)
%> @date $LastChangedDate: 2011-06-02 10:46:47 +0200 (Thu, 02 Jun 2011) $
%> @date Copyright 200x-20xx
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
%>	 BMoptMOSBO(samplesValuesPath)
%
% ======================================================================
%> @brief EGO BMoptMOSBO (kriging + EMO + ...)
% ======================================================================
% Modified by : Michael Mehari
% Email: mmehari@intec.ugent.be
function [newSample pred_obj] = BMoptMOSBO(samplesValuesPath)

% import samples and values data
samplesValueData = importdata(samplesValuesPath);
samplesValues = samplesValueData.data;

% bounds of the input variables
bounds = eval(samplesValueData.textdata{1});

inDimIdx =  (1:size(bounds,2));
outDimIdx = (size(bounds,2)+1:size(samplesValues,2));

nLengths = (bounds(2,:) - bounds(1,:))./bounds(3,:) + 1; % size of input variables

transl = (bounds(2,:) + bounds(1,:))/2.0;
scale = (bounds(2,:) - bounds(1,:))/2.0;
[inFunc, outFunc] = calculateTransformationFunctions( [transl; scale] );

samples = inFunc(samplesValues(:,inDimIdx));          % convert samples to simulator space
values = samplesValues(:,outDimIdx);

inDim = size(samples,2); % number of input variables
outDim = size(values,2); % number of objectives

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
optimizer = DiscreteOptimizer(inDim, 1, 'levels', nLengths);
optimizer = optimizer.setBounds(-ones(1,inDim), ones(1,inDim));

%% candidateRankers to use
rankers = {expectedImprovementHypervolume(ParetoFront(), inDim, 1, 'scaling', 'none') modelVariance(inDim, 1, 'scaling', 'none') };
 
%% main loop
% build and fit Kriging object
state.lastModels = cell(outDim,1);
for i=1:outDim
    state.lastModels{i}{1} = KrigingModel( opts, theta0, 'regpoly0', bf, 'useLikelihood' );
    state.lastModels{i}{1} = state.lastModels{i}{1}.constructInModelSpace( samples, values(:,i) );
end

% optimize it
state.samples = samples;
state.values = values;
for i=1:length(rankers)

    rankers{i} = rankers{i}.initNewSamples(state);
    
    %% optimize best candidate
    % give the state to the optimizer - might contain useful info such as # samples
    optimizer = optimizer.setState(state);

    optimFunc = @(x) rankers{i}.scoreMinimize(x, state);
    [~, xmin, fmin] = optimizer.optimize(optimFunc);

    % Predict objectives for each design parameter from the kringing model
    pred_obj = zeros(size(xmin,1), outDim);
    for j=1:outDim
        pred_obj(:,j) = state.lastModels{j}{1}.evaluateInModelSpace( xmin );
    end
    pred_obj = sortrows(pred_obj);

    dups = buildDistanceMatrix( xmin, samples, 1 );
    xmin = xmin(all(dups > distanceThreshold, 2),:);

    if ~isempty( xmin )
        break;
    end
    
    fprintf(1, 'No unique point found. Maxvar.\n');
end

if isempty( xmin )
    xmin = 2.*(rand(1,inDim) - 0.5);
    
    fprintf(1, 'No unique point found. Random.\n');
end
%% evaluate new samples and add to set    
newSample = outFunc(xmin(1,:));         % convert the new sample back to model space

end
