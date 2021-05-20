clc;
clear all;
close all;

[file,path] = uigetfile('*.oebin','Select Binary Open Ephys Structure File...');
data = load_open_ephys_binary(fullfile(path,file),'continuous',1);
sample_rate = data.Header.sample_rate;
total_length = numel(data.Timestamps)/sample_rate;  % length of the stream in seconds

%% Initially display all data for channel selection
ask = questdlg('Do you want to see the whole channel data?','Display?','Yes','No','No');
if strcmp(ask,'Yes')
    all_chan_num = length(data.Data(:,1));
    figure;
    for i = 1:all_chan_num
        subplot(6,5,i)
        plot(data.Data(i,:));
        title("CH"+num2str(i));
    end
end    

%% User input
prompt = {'Enter space-separated channel numbers to export:',
    'Enter the time window of the movie:',
    'Enter space-separated height and width of the movie:'
    'Enter frame rate of the movie (max 120):'
    'Enter tick numbers in the middle:'
    'Enter labels for each channel:'
    'Enter the thickness of the graph:'};
definput = {'17 18 19 20 22', '10','200 500','30','4','x;y;z;Pulse Pal;Azure TTL','0.5'};
    
answer = inputdlg(prompt,'Input', [1 50],definput);

ch_list = str2num(answer{1});
ch_num = numel(ch_list);

time_window = str2num(answer{2});
if time_window > total_length
    time_window = total_length;
end
plot_num = ceil(total_length/time_window);

vid_size = str2num(answer{3});

vid_fr = str2num(answer{4});
if vid_fr > 120
    vid_fr = 120;
end
total_frame_num = ceil(total_length*vid_fr);
frame_per_plot = time_window*vid_fr;

tick_num = str2num(answer{5});

ch_labels = strsplit(answer{6},';');
if length(ch_labels) ~= ch_num
    error('Not enough channel labels!');
end

line_width = str2num(answer{7});

%% Plot frames to temp folder
if ~isfolder('tmp')
    mkdir('tmp');
end

v = VideoWriter('output.avi');
v.FrameRate = vid_fr;
v.Quality = 95;
open(v)

text_margin = max(20,0.1*vid_size(1));
ch_height = round((vid_size(1)-text_margin)/ch_num);
ch_width = vid_size(2) - 2*text_margin;
pixel_per_sec = ch_width/time_window;
start_time = 0;
end_time = start_time + time_window;
color_list = {'w','g','m','y','c'};
    
for gn = 1:plot_num
    IM = zeros(vid_size(1),vid_size(2),3,'uint8');
    start_idx = start_time*sample_rate+1;
    end_idx = min(length(data.Data),end_time*sample_rate);
    for ch_idx = 1:ch_num
        f = figure('visible','off');
        %f = figure();
        h = axes;
        set(h,'position',[0 0 1 1])
        plot(data.Data(ch_list(ch_idx),start_idx:end_idx),color_list{mod(ch_idx,numel(color_list))+1},'LineWidth',line_width);
        a = [min(data.Data(ch_list(ch_idx),:)) max(data.Data(ch_list(ch_idx),:))];
        xlim([1 sample_rate*time_window]);
        ylim([a(1)-diff(a)*0.1 a(2)+diff(a)*0.1]);
        set(gca,'Color','k')
        set(gcf,'position',[10,300,ch_width,ch_height])
        set(gca,'xtick',[])
        set(gca,'xticklabel',[])
        set(gca,'ytick',[])
        set(gca,'yticklabel',[])
        set(gcf,'Resize','off')
        set(gcf,'PaperPositionMode','auto')
        set(gcf, 'InvertHardcopy', 'off')
        exportgraphics(f,"tmp/"+num2str(ch_list(ch_idx))+"_"+num2str(gn)+".png");
        %print("tmp/"+num2str(chan_list(ch_idx))+"_"+num2str(gn)+".png",'-dpng','-r0');
        close(f)
        tmp_im = imread("tmp/"+num2str(ch_list(ch_idx))+"_"+num2str(gn)+".png");
        tmp_im = imresize(tmp_im,[ch_height,ch_width]);
        IM(1+(ch_idx-1)*ch_height:ch_idx*ch_height,text_margin+1:vid_size(2)-text_margin,:) = tmp_im;
        IM = insertText(IM,[text_margin*1.2 text_margin*0+(ch_idx-1)*ch_height+ch_height*0.5],ch_labels{ch_idx},'FontSize',text_margin*0.5,'TextColor','white','BoxOpacity',0,'AnchorPoint','LeftCenter');
    end
    
    for i = 1:tick_num+2
        if time_window >= 1
            IM = insertText(IM,[text_margin+ch_width/(tick_num+1)*(i-1) ch_height*ch_num],num2str(start_time+(end_time-start_time)/(tick_num+1)*(i-1),'%.1f'),'FontSize',text_margin*0.5,'TextColor','white','BoxOpacity',0,'AnchorPoint','CenterTop');
        else
            IM = insertText(IM,[text_margin+ch_width/(tick_num+1)*(i-1) ch_height*ch_num],num2str(start_time+(end_time-start_time)/(tick_num+1)*(i-1),2),'FontSize',text_margin*0.5,'TextColor','white','BoxOpacity',0,'AnchorPoint','CenterTop');
        end
    end
%    IM = insertShape(IM,'Rectangle',[text_margin 1 ch_width vid_size(1)-text_margin],'LineWidth',max(1,round(text_margin*0.02)),'Color','white','Opacity',0.2);
    for i = 1:frame_per_plot
        IM2 = insertShape(IM,'Line',[text_margin+ch_width/frame_per_plot*(i-1) 1 text_margin+ch_width/frame_per_plot*(i-1) vid_size(1)-text_margin],'LineWidth',text_margin*0.1,'Color','red','Opacity',1);
        writeVideo(v,IM2)
    end
    
    start_time = start_time + time_window;
    end_time = end_time + time_window;
end

rmdir('tmp','s');

close(v);
