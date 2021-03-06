function [Itot, z_hits, newMap, varargout] = infoUGPVR(currentPose, map, S)

%{  
    Copyright (C) 2016  Maani Ghaffari Jadidi
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details. 
%}

param = map.param;
[~, ~, z_hits] = rayCasting([currentPose 0], param, map);
fp = scanLineSegmentationLocal({z_hits});
t = [z_hits, fp{1}]';

ids = [];
for j = 1:size(t,1)
    xi = t(j,:);
    idx = knnsearch(map.occMap, [xi(1), xi(2)]);
    ids = [ids; idx];
end

x = map.occMap.X(ids,:);
[n, ~] = size(x);
sn2 = exp(2*map.hyp.lik);
Sigma = S(1:2,1:2);
sW = ones(n,1)/sqrt(sn2);
covfunc = {@covUI, map.covfunc, 11, Sigma};

Kss = feval(covfunc{:}, map.hyp.cov, t, 'diag');
if issparse(Kss)
    K = sparse(feval(covfunc{:}, map.hyp.cov, x));
    Ks = sparse(feval(covfunc{:}, map.hyp.cov, x, t));
    L = sparse(chol(K/sn2+eye(n)));
    v = L'\ (repmat(sW,1,length(t)).*Ks);
    s2 = Kss - sum(v.*v,1)';
else
    K = feval(covfunc{:}, map.hyp.cov, x);
    Ks = feval(covfunc{:}, map.hyp.cov, x, t);
    L = chol(K/sn2+eye(n));
    v = L'\ (repmat(sW,1,length(t)).*Ks);
    s2 = Kss - sum(v.*v,1)';
end

Hprior = sum(log(map.Cov(ids)));
for j = 1:size(z_hits,2)
    if map.Cov(ids(j)) ~= 0 && s2(j) ~= 0
        map.Cov(ids(j)) = 1./(1./map.Cov(ids(j)) + 1./s2(j));
    end
end

Itot = Hprior - sum(log(map.Cov(ids)));
newMap = map;
varargout{1} = [];
