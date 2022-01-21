%
% Double Gamma function as defined in Prokopiou et al
%
% Prokopiou, P.C. et al, 2019. Modeling of dynamic cerebrovascular reactivity 
% to spontaneous and externally induced CO2 fluctuations in the human brain BOLD-fMRI. 
% Neuroimage 186, 533-548.
%
% Joe Whittaker (2021)

function y = gamma_pdf(P,x)

tau=P(1);
sigma=P(2);

for ii=1:length(x)
    
    t=x(ii);
    
    if t > 0
        
        a=exp(-t/sqrt(sigma*tau));
        b=(exp(1)*t)/tau;
        c=sqrt(tau/sigma);
        y(ii,:)=a*(b^c);
        
    else
        
        y(ii,:)=0;
        
    end
    
end