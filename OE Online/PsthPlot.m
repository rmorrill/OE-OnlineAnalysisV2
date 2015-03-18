function PsthPlot(duration, timewindow_padding, channel_plot, norm_spikes_per_trial, psth_fig_handle, subhandle, xy, x_sel, y_sel,  v_sel, o_sel, vo_cond)
	
% Histogram plot. Feb 9, 2015, Astra S. Bryant
%REALLY IMPORTANT: if this program is run in R2014b, histc may not work.
%replace with histcounts

% CHANGE THIS TO CHANGE NO. OF BINS: 
bin_count = 50; 

%% Get data into plottable formation
% RJM EDIT - this should no longer be necesary
% if strmatch('Time (zoom)', x_sel,'exact')
% 	duration=.16;
% 	binvals={[.1:(duration/80):.1+duration]};
% 	binwidth=duration/80;
%
% else
binvals={[0:(duration/bin_count):duration]};
binwidth=duration/bin_count;

% end

histbins=repmat(binvals, size(norm_spikes_per_trial,1), 1);

bincounts = cellfun(@histc, norm_spikes_per_trial, histbins, 'UniformOutput',false)';
for x=1:size(bincounts,1)
	if isempty (bincounts{x})
		bincounts{x}=zeros(1,size(binvals{1},2));
		
	end
end
bincounts = cell2mat(bincounts'); %array with trials by binvals

%sumcounts = sum(bincounts,1);

%Separate into V_val and O_val conditions


%Separate into Y_val condition
[B,~,J] = unique(xy, 'rows'); % J contains indices that group by stimulus paramaters
ind=J(1:size(bincounts,1));
for x=1:size(B, 1)
 sumcounts(x,:)= mean(bincounts(find(ind==x),:),1);
end

%% Plotting
if ~isempty(v_sel)
	if vo_cond(1)<1
		vis_stat='';
	else
		vis_stat='{\color{gray}Vis Stim On}';
	end
else
	vis_stat='';
end
if ~isempty(o_sel)
	if ~isempty(v_sel)
		if vo_cond(2)<1
			opto_stat='';
		else
			opto_stat='{\color{blue}Opto Light On}';
		end
	else
		if vo_cond(1)<1
			opto_stat='';
		else
			opto_stat='{\color{blue}Opto Light On}';
		end
		
	end
else
	opto_stat='';
end
figure(psth_fig_handle)

%title/figure naming
if ~isempty(vis_stat) & ~isempty(opto_stat)
	set(psth_fig_handle, 'Name',sprintf('Channel %d PSTH, Vis Stim and Opto Light On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d PSTH, %s, %s',channel_plot,vis_stat, opto_stat)]);
elseif ~isempty(vis_stat)
	set(psth_fig_handle, 'Name',sprintf('Channel %d PSTH, Vis Stim On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d PSTH, %s',channel_plot,vis_stat)]);
elseif ~isempty(opto_stat)
	set(psth_fig_handle, 'Name',sprintf('Channel %d PSTH, Opto Light On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d PSTH, %s',channel_plot,opto_stat)]);	
else
	set(psth_fig_handle, 'Name',sprintf('Channel %d PSTH',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d PSTH',channel_plot)]);
end
 
 
for x=1:size(B,1)
	hold off
	subplot(subhandle{x})
	bar(subhandle{x},binvals{1}, sumcounts(x,:), 'FaceColor', [.25, .25, .25]);
	hold on
	%axis tight;
	axis manual
	%ylim([0 ceil(max(max(sumcounts)))]);
	ylim([0 (max(max(sumcounts)))]);
	xlim([(binvals{1}(1)-0.016) (binvals{1}(end)+.016)]);
	
	%Add red lines indicating stimulus onset
% 	plot([0.15 0.15], ylim, 'r');
% 	plot([0.15+(duration-.3) 0.15+(duration-.3)], ylim, 'r');
 	plot([timewindow_padding(1) timewindow_padding(1)], ylim, 'r');
 	plot([timewindow_padding(1)+(duration-sum(timewindow_padding)) timewindow_padding(1)+(duration-sum(timewindow_padding))], ylim, 'r');
	
	%bar(binvals{1}, bincounts', 'stacked');
	%colormap(summer);
	

	%h=title( sprintf('%s : %.2g',y_sel,B(x)), 'FontSize', 12); %scientific
	%notation version of titles.
	h=title(strcat(y_sel,{': '},num2str(B(x))), 'FontSize', 8, 'FontWeight','bold');
	set(h, 'interpreter','none') %removes tex interpretation rules
	
	xticklabels=num2str((str2num(get(subhandle{x}, 'XTickLabel')).*1000)-(timewindow_padding(1)*1000));
	set(subhandle{x},'XTickLabel',xticklabels, 'fontsize',6);
	xlabel('Time (ms)', 'FontSize', 6);
	ylabel('Spikes/Trial', 'FontSize', 6);

end

	filepath= cd;
	print(gcf,'-dpng',fullfile(filepath, get(gcf,'Name')));


end
