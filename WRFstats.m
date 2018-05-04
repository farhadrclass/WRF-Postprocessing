%:------------------------------------------------------------------------- 
% Script for comparing On-site measurements to WRF output variables.
% 
% Strukture of the script: 
%   1) Reading WRF output data from MAT-tables. The tables are generated by
%   the script "DataExtraction_1domain.m" and meant for running at Stallo.
% 
% 
% Last updated: 02.May.2018, Torgeir
%:------------------------------------------------------------------------- 

close all
clear all
clc

addpath ../MatlabFunctions/WindRose
addpath ../MatlabFunctions

% Decalre time of interest
dd = 13;   
mm = 01;
yyyy = 2015;


% ---- 1) WRF data --------------------------------------------------------
eta = 4;

d01 = load(strcat('../WRF_dataextracts/Simulation_', ...
           num2str(dd, '%02d'), num2str(mm, '%02d'), num2str(yyyy), ...
           'Domain1.mat'));
d02 = load(strcat('../WRF_dataextracts/Simulation_', ...
           num2str(dd, '%02d'), num2str(mm, '%02d'), num2str(yyyy), ...
           'Domain2.mat'));
       
% Wind speed and direction
WS_d01 = sqrt(d01.u(4, :).^2 + d01.v(4, :).^2);
WD_d01 = cart2compass(d01.u(4, :), d01.v(4, :));

WS_d02 = sqrt(d02.u(4, :).^2 + d02.v(4, :).^2);
WD_d02 = cart2compass(d02.u(4, :), d02.v(4, :));

% Temperature (from potential temp.)
Rd  = 287;      % Gas constant for dry air [J/(kgK)]
Rw  = 461.4;    % Gas constant for water vapor [J/(kgK)]
c_pd = 7*Rw/2;  % Spec. heat cap. dry air @ const. press. [J(kgK)]
c_pw = 4*Rw;    % Spec. heat cap. water vapor @ const press [J/(kgK)]
% Poisson constant
Kappa_d01 = (Rd*(1 - d01.qvapor(eta, :)) + Rw*d01.qvapor(eta, :))./...
            (c_pd*(1 - d01.qvapor(eta, :)) + c_pw*d01.qvapor(eta, :));

temp_d01 = (295 + d01.thetap(eta, :)).*...
           ((d01.pb(eta, :) + d01.pp(eta, :))./d01.psfc').^Kappa_d01;

Kappa_d02 = (Rd*(1 - d02.qvapor(eta, :)) + Rw*d02.qvapor(eta, :))./...
            (c_pd*(1 - d02.qvapor(eta, :)) + c_pw*d02.qvapor(eta, :));

temp_d02 = (295 + d02.thetap(eta, :)).*...
           ((d02.pb(eta, :) + d02.pp(eta, :))./d02.psfc').^Kappa_d02;

% % Relative humidity
% e = 0.01*exp(-2991.2729*temp_d01.^(-2) ...
%     - 6017.0128.*temp_d01.^(-1) + 18.87643854 ...
%     - 0.028354721.*temp_d01 + 0.17838301e-4*temp_d01.^2 ...
%     - 0.84150417e-9*temp_d01.^3 + 0.44412543e-12.*temp_d01.^4 ...
%     + 2.858487*log(temp_d01));
% 
% temp = 54.842763 - 6763.22./temp_d01 - 4.210.*log(temp_d01) + ...
%        0.000367.*temp_d01 + tanh(0.0415*(temp_d01 - 218.8)) ...
%        .*(53.878 - 1331.22./temp_d01 - 9.44523.*log(temp_d01) + 0.014025.*temp_d01);
% es = exp(temp);
% 
% rh = 100.*e./es;

% Tidy up
clear Rd Rw c_* Kappa*


% ---- In-situ data, T01 -------------------------------------------------- 
% Read datasetsdepending on the year of the icing event
if yyyy == 2013
    if mm == 11
        xlfileT01 = '../OnsiteData/icing events/2013.11.15.T1.xlsx';
    elseif mm == 12
        xlfileT01 = '../OnsiteData/icing events/2013.12.11.T1.xlsx';
    end
        
    [xlnum, xlcell] = xlsread(xlfileT01);
    WS_obs = xlnum(:, 9);
    WD_obs = xlnum(:, 7);
    Tobs = xlnum(:, 3);

    % Timecolumn not readable. Creating a new
    obsTime = linspace(min(d01.timenum), max(d01.timenum), ...
                       length(d01.timenum));
       
elseif yyyy == 2014
    
    xlfileT01 = '../OnsiteData/merged2014T1.xlsx';
    [xlnum, xlcell] = xlsread(xlfileT01);
    % Convert cell-strings to double
    xlyy = str2double(xlcell(2:length(xlcell), 3));
    xlmm = str2double(xlcell(2:length(xlcell), 4));
    xldd = str2double(xlcell(2:length(xlcell), 5));

    % Find start and end index all elements matching datevec
    timeIndx = find(xlyy == yyyy & xlmm == mm & xldd == dd);
    timenum = datenum(strcat(xlcell(timeIndx, 5), '/', xlcell(timeIndx, 4), ...
                      '/', xlcell(timeIndx, 3), '-', xlcell(timeIndx, 6)), ...
                      'dd/mm/yyyy-HH');
    % The temporal resolution is not minutes. Dirty trick to manipulate this:
    obsTime = linspace(min(timenum), max(timenum), length(timenum));
    Tobs = xlnum(timeIndx, 8);
    WS_obs = xlnum(timeIndx, 14);
    WindDir_obs = xlnum(timeIndx, 11);

    indWD = find(WindDir_obs < 0);
    WindDir_obs(indWD) = WindDir_obs(indWD) + 360;  % Convert -180,180 -> 0 360
    WD_obs = FlipWindDir(WindDir_obs);

elseif yyyy == 2015
    if dd == 10
        xlfileT01 = '../OnsiteData/icing events/2015.01.10.T1.xlsx';
    elseif dd ==13
        xlfileT01 = '../OnsiteData/icing events/2015.01.13.T1.xlsx';
    end
    [xlnum, xlcell] = xlsread(xlfileT01);
    WS_obs = xlnum(:, 9);
    WindDir_obs = xlnum(:, 7);
    indWD = find(WindDir_obs < 0);
    WindDir_obs(indWD) = WindDir_obs(indWD) + 360;  % Convert -180,180 -> 0 360
    WD_obs = FlipWindDir(WindDir_obs);
    Tobs = xlnum(:, 3);

    % Timecolumn not readable. Creating a new
    obsTime = linspace(min(d01.timenum), max(d01.timenum), ...
                       length(d01.timenum));
end
    
clear xl* timeIndx WindDir indWD



% ---- Correlation coefficients -------------------------------------------
% Find times that correspond in both WRF and OBS data
tmin_obs = min(obsTime);        tmax_obs = max(obsTime);
tmin_d01 = min(d01.timenum);    tmax_d01 = max(d01.timenum);

if tmin_obs < tmin_d01
    tmin = tmin_d01;
else
    tmin = tmin_d01;
end

if tmax_obs < tmax_d01
    tmax = tmax_obs;
else 
    tmax = tmax_d01;
end

indObs = find(tmin <= obsTime & obsTime <= tmax);
indD01 = find(tmin <= d01.timenum & d01.timenum <= tmax);
indD02 = find(tmin <= d02.timenum & d02.timenum <= tmax);


% Compute correlation if same dimensions
if length(indObs) == length(indD01)
    % Wind speed
    [rho_WSd01, pvalue_WSd01] = corrcoef(WS_d01(indD01), WS_obs(indObs));
    [rho_WSd02, pvalue_WSd02] = corrcoef(WS_d02(indD02), WS_obs(indObs));

    % Temperature
    [rho_T2d01, pvalue_T2d01] = corrcoef(d01.t2(indD01), Tobs(indObs));
    [rho_T2d02, pvalue_T2d02] = corrcoef(d02.t2(indD02), Tobs(indObs));
    [rho_tempd01, pvalue_tempd01] = corrcoef(temp_d01(indD01), Tobs(indObs));
    [rho_tempd02, pvalue_tempd02] = corrcoef(temp_d02(indD02), Tobs(indObs));
% If dimensionality inequality, in-situ variables are interpolated to match
% the WRF-dimensions. 
else 
    disp(strcat('Dimensions not equal. In-situ data is interpolated', ...
        ' to match the WRF-data dimensions.'))
    
    % Linear interpolation and computing correlation coeffs
    % Wind speed
    obsWSInterp = interp1(obsTime(indObs), WS_obs(indObs)', ...
                  d01.timenum(indD01), 'linear', 'extrap');
              
    [rho_WSd01, pvalue_WSd01] = corrcoef(WS_d01(indD01), obsWSInterp);
    [rho_WSd02, pvalue_WSd02] = corrcoef(WS_d02(indD02), obsWSInterp);
    
    % Temperature
    TobsInterp = interp1(obsTime(indObs), Tobs(indObs)', ...
                 d01.timenum(indD01), 'linear', 'extrap');
    [rho_T2d01, pvalue_T2d01] = corrcoef(d01.t2(indD01), TobsInterp);
    [rho_T2d02, pvalue_T2d02] = corrcoef(d02.t2(indD02), TobsInterp);
    
    [rho_tempd01, pvalue_tempd01] = corrcoef(temp_d01(indD01), TobsInterp);
    [rho_tempd02, pvalue_tempd02] = corrcoef(temp_d02(indD02), TobsInterp);
end
    
% Tidy up
clear ind* tmin* tmax*



% ---- FIGURES ------------------------------------------------------------
fontsz = 14;

% Wind Magnitude
fig1 = figure(1);
hold all
pd01 = plot(d01.timenum, WS_d01, '.-');
pd02 = plot(d02.timenum, WS_d02, '.-');
pobs = plot(obsTime, WS_obs, '.-');

% Annotate correlation coefficients
text(obsTime(120), min(WS_d02) + 1.5, ...
     strcat('\rho(WSd01, WSobs) = ', num2str(rho_WSd01(1, 2))), ...
     'FontSize', fontsz)
text(obsTime(120), min(WS_d02) + .5, ...
     strcat('\rho(WSd02, WSobs) = ', num2str(rho_WSd02(1, 2))), ...
     'FontSize', fontsz)

% Appearance
xlim([min(d01.timenum)-.05 max(d01.timenum)+.05])
set(gca, 'FontSize', fontsz)
ylabel('Wind speed [m/s]')
set(gca, ...
    'TickLength'  , [.01 .01] , ...
    'XMinorTick'  , 'on'      , ...
    'YMinorTick'  , 'on'      , ...
    'YGrid'       , 'on'      , ...
    'XColor'      , [.3 .3 .3], ...
    'YColor'      , [.3 .3 .3], ...
    'xtick', d01.timenum(1:14.5:length(d01.timenum)), ...
    'ticklength', [2e-3 2e-3], ...
    'xticklabel', datestr(d01.timenum(1:14.5:length(d01.timenum)), ...
    'dd/mmm-HH:MM:SS'));
rotateXLabels(gca(),60)
legend([pd01 pd02 pobs], 'Domain 1', 'Domain 2', 'Obs. T01')
set(fig1, 'Position', [200 300 1500 500])
% save2pdf(strcat('../Figures/Comparing_WRF_Obs/Windspeed_', ...
%          num2str(dd, '%02d'), num2str(mm, '%02d'), num2str(yyyy), '.pdf'))



% Wind Roses
fig2 = figure(2);
sb1 = subplot(1, 4, 1);
[theta_d01, rd01] = rose(degtorad(WD_d01), degtorad(0:10:350));
[theta_d02, rd02] = rose(degtorad(WD_d02), degtorad(0:10:350));
[theta_obs, rObs] = rose(degtorad(WD_obs), degtorad(0:10:350));
pold01 = polarplot(theta_d01, rd01/length(theta_d01));            hold on
pold02 = polarplot(theta_d02, rd02/length(theta_d02));            hold on
polObs = polarplot(theta_obs, rObs/length(theta_obs));       
rlim([0 .8])
ax = gca;
ax.RAxisLocation = 90;    
ax.ThetaAxisUnits = 'degrees';
ax.ThetaZeroLocation = 'top';
ax.ThetaDir = 'clockwise';
lgd = legend([pold01 pold02 polObs], 'Domain 1', 'Domain 2', 'Obs. T01');
set(lgd, 'Position', [0.3074999 0.6787500 0.066667 0.044167]);

sb2 = subplot(1, 4, 2);
WindRose(sb2, WD_obs, WS_obs, ...
         0:30:330, 2.5:5:37.5, 0:20:100, 'Obs. T01');

sb3 = subplot(1, 4, 3);
WindRose(sb3, WD_d01, WS_d01, ...
         0:30:330, 2.5:5:37.5, 0:20:100, 'Domain 1');

sb4 = subplot(1, 4, 4);
WindRose(sb4, WD_d02, WS_d02, ...
         0:30:330, 2.5:5:37.5, 0:20:100, 'Domain 2');

     
% Appearance
set(gca, 'FontSize', fontsz)
set(fig2, 'Position', [0 100 1600 600])
% save2pdf(strcat('../Figures/Comparing_WRF_Obs/WindDirection_', ...
%          num2str(dd, '%02d'), num2str(mm, '%02d'), num2str(yyyy), '.pdf'))


% Temperature
fig3 = figure(3);
hold all
plot_temp2m_d01 = plot(d01.timenum, d01.t2, '.-');
plot_temp60m_d01 = plot(d01.timenum, temp_d01, '--');
plot_temp2m_d02 = plot(d02.timenum, d02.t2, '.-');
plot_temp60m_d02 = plot(d02.timenum, temp_d02, '--');
plot_Tobs1 = plot(obsTime, Tobs + 273.15, '.-');

% Annotate correlation coefficients
text(d01.timenum(1), double(max(temp_d02)) + 2.4, ...
     strcat('\rho(T2d01, Tobs) = ', num2str(rho_T2d01(1, 2))), ...
     'FontSize', fontsz)
text(d01.timenum(1), double(max(temp_d02)) + 1.6, ...
     strcat('\rho(T2d02, Tobs) = ', num2str(rho_T2d02(1, 2))), ...
     'FontSize', fontsz)
text(d01.timenum(1), double(max(temp_d02)) + .8, ...
     strcat('\rho(T60d01, Tobs) = ', num2str(rho_tempd01(1, 2))), ...
     'FontSize', fontsz)
text(d01.timenum(1), double(max(temp_d02)), ...
     strcat('\rho(T60d02, Tobs) = ', num2str(rho_tempd02(1, 2))), ...
     'FontSize', fontsz)

% Appearance
set(gca, 'FontSize', fontsz)
xlim([min(d01.timenum)-.05 max(d01.timenum)+.05])
ylabel('Temperature [K]')
set(gca, ...
    'TickLength'  , [.01 .01] , ...
    'XMinorTick'  , 'on'      , ...
    'YMinorTick'  , 'on'      , ...
    'YGrid'       , 'on'      , ...
    'XColor'      , [.3 .3 .3], ...
    'YColor'      , [.3 .3 .3], ...
    'xtick', d01.timenum(1:14.5:length(d01.timenum)), ...
    'ticklength', [2e-3 2e-3], ...
    'xticklabel', datestr(d01.timenum(1:14.5:length(d01.timenum)), ...
    'dd/mmm-HH:MM:SS'));
rotateXLabels(gca(),60)
legend([plot_temp2m_d01 plot_temp60m_d01 ...
        plot_temp2m_d02 plot_temp60m_d02 plot_Tobs1], ...
       'Domain 1 @ 2 m', 'Domain 1 @ 60 m', ...
       'Domain 2 @ 2 m', 'Domain 2 @ 60 m', 'Temp @ T01')
set(fig3, 'Position', [200 300 1600 500])
save2pdf(strcat('../Figures/Comparing_WRF_Obs/Temperature_', ...
         num2str(dd, '%02d'), num2str(mm, '%02d'), num2str(yyyy), '.pdf'))


