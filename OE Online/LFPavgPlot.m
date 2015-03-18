function LFPavgPlot(duration, timewindow_padding, channel_plot, waves, psth_fig_handle, subhandle, xy, x_sel, y_sel,  v_sel, o_sel, vo_cond, sfq)
	
% LFP average plot. Feb 25, 2015, Astra S. Bryant


%% Get data into plottable formation
%Separate into V_val and O_val conditions


%Separate into Y_val condition
[B,~,J] = unique(xy, 'rows'); % J contains indices that group by stimulus paramaters
ind=J(1:size(waves,1));
for x=1:size(B, 1)
 waveplots(x,:)= mean(waves(find(ind==x),:));
 wavestd(x,:)=std(waves(find(ind==x),:));
end
times=[1:length(waveplots(1,:))]./sfq;

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
	set(psth_fig_handle, 'Name',sprintf('Channel %d Mean LFP, Vis Stim and Opto Light On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d Mean LFP, %s, %s',channel_plot,vis_stat, opto_stat)]);
elseif ~isempty(vis_stat)
	set(psth_fig_handle, 'Name',sprintf('Channel %d Mean LFP, Vis Stim On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d Mean LFP, %s',channel_plot,vis_stat)]);
elseif ~isempty(opto_stat)
	set(psth_fig_handle, 'Name',sprintf('Channel %d Mean LFP, Opto Light On',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d Mean LFP, %s',channel_plot,opto_stat)]);	
else
	set(psth_fig_handle, 'Name',sprintf('Channel %d Mean LFP',channel_plot),'NumberTitle','off');
	suptitle([sprintf('Channel %d Mean LFP',channel_plot)]);
end
 
 
for x=1:size(B,1)
	hold off
	subplot(subhandle{x})
	 shadedErrorBar(times,waveplots(x,:),wavestd(x,:));
	hold on
	%axis tight;
	%axis manual
	
	%Add red lines indicating stimulus onset
% 	plot([0.15 0.15], ylim, 'r');
% 	plot([0.15+(duration-.3) 0.15+(duration-.3)], ylim, 'r');
 	plot([timewindow_padding(1) timewindow_padding(1)], ylim, 'r');
 	plot([timewindow_padding(1)+(duration-sum(timewindow_padding)) timewindow_padding(1)+(duration-sum(timewindow_padding))], ylim, 'r');
		
	%adding lines that mark off every 50 ms. If click stimulus is at 20 Hz,
	%there they will occur every 50 ms.
	%for x=0.15:.05:(0.15+(duration-.3));
    for y= timewindow_padding(1):.05:timewindow_padding+(duration-sum(timewindow_padding)); %replace the .05 with the frequency of firing
	plot([y y], ylim/5, 'w');
	end
	%bar(binvals{1}, bincounts', 'stacked');
	%colormap(summer);
	

	%h=title( sprintf('%s : %.2g',y_sel,B(x)), 'FontSize', 12); %scientific
	%notation version of titles.
	h=title(strcat(y_sel,{': '},num2str(B(x))), 'FontSize', 8, 'FontWeight','bold');
	set(h, 'interpreter','none') %removes tex interpretation rules
	
	xticklabels=num2str((str2num(get(subhandle{x}, 'XTickLabel')).*1000)-(timewindow_padding(1)*1000));
	set(subhandle{x},'XTickLabel',xticklabels, 'fontsize',6);
	xlabel('Time (ms)', 'FontSize', 6);
	ylabel('microVolts', 'FontSize', 6);
	
end

	filepath= cd;
	print(gcf,'-dpng',fullfile(filepath, get(gcf,'Name')));


end
