clear all;

% set the seed
rand('seed',6);

% set the number of iterations
REP=200;

% N: total sample size, m: number of machines, n: local sample size, p: dimension, T: number of iterations
N=10000;
m=100;
n=N/m;
p=6;
T=20;

% fraction of Byzantine machines
alpha=0.2;

% threshold parameter for the trimmed mean
xi=0.2;

% set parameters
lambda=0.01;
eta=1/(sqrt(p)+lambda);

% true beta for the model
sigma=1;
center = ones(1,p);
fun = @(x) normpdf(x,p,norm(center)*sigma*sqrt(p)).*x;
g = @(x) integral(fun,-inf,x);
rho = fzero(g,0);
beta_true = ones(p,1)/rho;

for rep=1:REP
    randn('state',rep)
    
    % compute the initial estimator
    y0 = 2*(randn(n,1)>0)-1;
    x0 = norm(center)*sigma*randn(n,p)+y0*center;
    cvx_begin quiet
    variable b(p,1)
    minimize sum(max(1-y0.*(x0*b),0))
    cvx_end
    
    % estimate of vanilla distributed gradient descent algorithm without Byzantine attacks
    beta_mean0 = b;
    % estimate of vanilla distributed gradient descent algorithm under extreme attacks
    beta_mean_ex = b;
    % estimate of median-based distributed gradient descent algorithm under extreme attacks
    beta_median_ex = b;
    % estimate of trimmed-mean-based distributed gradient descent algorithm under extreme attacks
    beta_trim_ex = b;
    
    % generate data
    y = 2*(randn(N,1)>0)-1;
    x = norm(center)*sigma*randn(N,p)+y*center;
    
    for t=1:T
        for k=1:m
            ym=y(((k-1)*n+1):(k*n),:);
            xm=x(((k-1)*n+1):(k*n),:);
            G_mean0(k,:)=-1/m*sum(xm.*repmat(ym.*max(sign(1-ym.*(xm*beta_mean0)),0),1,p))+lambda*beta_mean0';
            G_mean_ex(k,:)=-1/m*sum(xm.*repmat(ym.*max(sign(1-ym.*(xm*beta_mean_ex)),0),1,p))+lambda*beta_mean_ex';
            G_median_ex(k,:)=-1/m*sum(xm.*repmat(ym.*max(sign(1-ym.*(xm*beta_median_ex)),0),1,p))+lambda*beta_median_ex';
            G_trim_ex(k,:)=-1/m*sum(xm.*repmat(ym.*max(sign(1-ym.*(xm*beta_trim_ex)),0),1,p))+lambda*beta_trim_ex'; 
        end
        
        % extreme random attack
        G_mean_ex(1:(m*alpha),:)=unifrnd (-100,100,m*alpha,p);
        G_median_ex(1:(m*alpha),:)=unifrnd (-100,100,m*alpha,p);
        G_trim_ex(1:(m*alpha),:)=unifrnd (-100,100,m*alpha,p);
        
        g_mean0 = mean(G_mean0);
        g_mean_ex = mean(G_mean_ex);
        g_median_ex = median(G_median_ex);
        g_trim_ex = trimmean(G_trim_ex,2*xi*100);
        
        % update the estimates
        beta_mean0 = beta_mean0-eta*g_mean0';
        beta_mean_ex = beta_mean_ex-eta*g_mean_ex';
        beta_median_ex = beta_median_ex-eta*g_median_ex';
        beta_trim_ex = beta_trim_ex-eta*g_trim_ex';
        
        % generate test data
        ytest = 2*(randn(N,1)>0)-1;
        xtest = norm(center)*sigma*randn(N,p)+ytest*center;
        
        acc_mean0(rep,t) = sum(sign(xtest*beta_mean0).*ytest>0)/N;
        acc_mean_ex(rep,t) = sum(sign(xtest*beta_mean_ex).*ytest>0)/N;
        acc_median_ex(rep,t) = sum(sign(xtest*beta_median_ex).*ytest>0)/N;
        acc_trim_ex(rep,t) = sum(sign(xtest*beta_trim_ex).*ytest>0)/N;
    end   
end
% compute accuracies
A_mean0=mean(acc_mean0);
A_mean_ex=mean(acc_mean_ex);
A_median_ex=mean(acc_median_ex);
A_trim_ex=mean(acc_trim_ex);

% output the final accuracies
[A_mean0(T), A_mean_ex(T), A_median_ex(T), A_trim_ex(T)]