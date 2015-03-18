function HeatPlot (spike_data, yx, y_idx, x_idx, nr_uniq_x, nr_uniq_y, uniq_x, uniq_y, y_sel, x_sel, channel_plot, heat_fig_handle,vo_cond, timewindow)
% Heat plot. Feb 5, 2015, Astra S. Bryant/Ryan Morrill
%
% spike_data_padded=zeros(totaltrialno,1);
% 	spike_data_padded(1:trialcount)=spike_data;
%
% 	[B,~,J] = unique(xy, 'rows'); % J contains indices that group by stimulus paramaters
% 	%only average cells in the spike_data_padded array where the spike
% 	%count is greater than zero. Otherwise, will get averaging error as
% 	%values are filled in with increasing trial numbers.
% 	data_avg = accumarray(J(find(spike_data_padded>0)), spike_data_padded(find(spike_data_padded>0)), [size(B,1) 1], @mean); % apply mean to each group of data, return size(B,1) averages, sorted
% 	% sort by y value for plotting?
% 	[~,y_sort_idx] = sort(B(:,y_idx));
% 	data_avg_sort = data_avg(y_sort_idx);
%
% 	data_rs = reshape(data_avg_sort, nr_uniq_x, nr_uniq_y)';
% 	%data_rs
% updated Feb 26, 2015 RJM
% mods needed: use flipud to flip intensity axis 

%spike_data = 1:1400; 
[B,~,J] = unique(yx, 'rows'); % J contains indices that group by stimulus paramaters
%only average cells in the spike_data_padded array where the spike
%count is greater than zero. Otherwise, will get averaging error as
%values are filled in with increasing trial numbers.

data_avg = accumarray(J, spike_data', [size(B,1) 1], @nanmean);
% sort by y value for plotting?
data_rs = reshape(data_avg, nr_uniq_x, nr_uniq_y)';

%% Plotting

% % 	if ~exist('fig_handle')
% % 			%If it doesn't already exist, then create it - otherwise use
% % 			%the old one
% % 		fig_handle = figure;
% % 	end
if vo_cond(1)<1
    vis_stat='No Vis Stim';
else
    vis_stat='Vis Stim On';
end
if vo_cond(2)<1
    opto_stat='No Opto Light';
else
    opto_stat='Opto Light On';
end



figure(heat_fig_handle)
set(heat_fig_handle, 'Name',sprintf('Channel %d, %s, %s',channel_plot,vis_stat, opto_stat),'NumberTitle','off');
hold off
%figure
% RJM MOD
% maxval = max(data_rs(:));
% data_rs(isnan(data_rs)) = maxval + maxval/20; % make nans a bit higher than the highest val 
data_rs(isnan(data_rs)) = -0.1; 
clims=[-.1 max(max(data_rs))];
% clims=[min(min(data_rs)) max(max(data_rs))];

%imagesc(data_rs, clims) % RJM 
imagesc(data_rs); 
%END RJM MOD
%imagesc(data_rs,[min(data_avg_sort(find(data_avg_sort>0)))-2,max(data_avg_sort(find(data_avg_sort>0)))]);
hold on
axis xy


% %%% RJM EDIT 
% cmap=colormap(jet(255));
% %cmap = flipud([254:-1:0; zeros(1,255); zeros(1,255)]'/254);
% % colormap(flipud([255:-1:0; zeros(1,256); zeros(1,256)]'/255));
% %cmap=colormap();
% 
% cmap=[.7 .7 .7;cmap]; % makes lowest val light gray
% colormap(cmap);
% colorbar();
% %%%%%% RJM EDIT

h=ylabel(y_sel, 'FontSize', 8);
set(h, 'interpreter','none') %removes tex interpretation rules
h=xlabel(x_sel, 'FontSize', 8);
set(h, 'interpreter','none') %removes tex interpretation rules

set(gca, 'YTick', [1:nr_uniq_y]);
set(gca, 'YTickLabel', uniq_y);
set(gca, 'XTick', [1:nr_uniq_x]);
set(gca, 'XTickLabel', uniq_x);
set(gca,'fontsize',8);
%title(sprintf('Channel %d, Time: %s-%s s, %s, %s',channel_plot,num2str(timewindow(1)-.15), num2str(timewindow(2)-.15), vis_stat, opto_stat),'FontSize',10);
title(sprintf('Channel %d, Time: %s-%s s, %s, %s',channel_plot,num2str(timewindow(1)), num2str(timewindow(2)), vis_stat, opto_stat),'FontSize',10);


filepath= cd;
print(gcf,'-dpng',fullfile(filepath, get(gcf,'Name')));

end