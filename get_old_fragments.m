% creates separate image for each fragment on the old plates

% where the masks are 
SEG_DIR = fullfile('DATA', 'OLD_UNSEGMENTED', 'masks');

% where unsegmented grayscale images are
UNSEG_DIR = fullfile('DATA', 'OLD_UNSEGMENTED', 'plates');

% stores the fragments
RES_DIR = fullfile('DATA', 'OLD_SEGMENTED', 'fragment');

% stores the masks so we can view the location later
RES_DIR_FULLIMAGES = fullfile('DATA', 'OLD_SEGMENTED', 'plate');
    
% get list of all masks
masks = dir(fullfile(SEG_DIR, '*.png'));

% we keep connected components only if the overlap threshold between it and
% the other connected components is greater than this when we are using the
% hamming distance
overlap_threshold = 0.1; 

% iterate and get the connected components for each plate
for ind=1:size(masks,1)   
    plate_name = masks(ind).name(1:10);
    pname = dir(fullfile(UNSEG_DIR,strcat(plate_name,'*.jpg')));
    plate_name = pname.name(1:end-4);
    fprintf('going through mask %s\n', masks(ind).name);
    % assuming here that the image is uint8 and grayscale
    gray_plate = imread(fullfile(UNSEG_DIR,pname.name));
    
    if size(gray_plate,3) == 3
        gray_plate = rgb2gray(gray_plate);
    end
    mask = imread(fullfile(SEG_DIR, masks(ind).name));
    if size(mask,3) == 3
        mask = rgb2gray(mask);
    end
    
    % mask may be smaller because we can find the segmentations by making
    % the plates much smaller and then running the Deep Segmentation --
    % here we make it bigger again
    mask = imresize(mask, size(gray_plate));
    mask = imopen(mask, strel('disk', 10));
    mask = logical(mask);
    
    % find separate connected components and save them to the specific
    % folder for the current directory
    PLATE_FOLDER = fullfile(RES_DIR,plate_name);
    PLATE_FOLDER_FULL_BW = fullfile(RES_DIR_FULLIMAGES,plate_name);
    
    % check if the folder exists first 
    if exist(PLATE_FOLDER,'dir') ~= 7
        mkdir(PLATE_FOLDER);
    end
    if exist(PLATE_FOLDER_FULL_BW,'dir') ~= 7
        mkdir(PLATE_FOLDER_FULL_BW);
    end
    
    % find and keep the correct connected components 
    template_stats = regionprops(mask,'BoundingBox','Centroid','Area','PixelIdxList','ConvexHull','Image','MajorAxisLength','MinorAxisLength','Orientation');
    min_area = 6400; % need to be something like an 80x80 square image 
    
    files = dir(fullfile(PLATE_FOLDER,'*.png'));
    save_num = size(files,1) + 1;
    compare_distances_up_to = size(files,1); % we don't compare fragments within
    % a bw image to each other -- because it's wasted computation
    fprintf('going through mask %s has %s fragments \n', masks(ind).name, num2str(length(template_stats)));
    for cc_ind=1:length(template_stats)
        % make make sure the major axis and minor axis makes sense
        % if it's too long (a long line), then get rid of it
        cc = template_stats(cc_ind); 
        bbox = template_stats(cc_ind).BoundingBox; 
        
        extra_area = 0; % add extra_area number of extra pixels to each fragment borders 
        
        if cc.Area > min_area
            bw_img = cc.Image;
            
            % get a single fragment

            % convert the indices
            [a,b]  = ind2sub(size(gray_plate),cc.PixelIdxList);
            a2 = a - min(a) + 1; b2 = b - min(b) + 1;

            % initialize an empty image
            cc_grayscale = uint8(zeros(size(cc)));
            M = length(a);
            for index=1:M
                cc_grayscale(a2(index),b2(index)) =  gray_plate(a(index),b(index));
            end

            big_cc_grayscale = uint8(zeros(size(cc_grayscale,1) + extra_area*2,...
                              size(cc_grayscale,2) + extra_area*2));
                          
            big_cc_grayscale(extra_area + 1:size(big_cc_grayscale,1) - extra_area,...
            extra_area + 1:size(big_cc_grayscale,2) - extra_area) = cc_grayscale;
            
            full_bw = zeros(size(gray_plate));
            full_bw(template_stats(cc_ind).PixelIdxList)=1;
            
            small_full_bw = imresize(full_bw, 0.1); 
            small_full_bw = logical(small_full_bw); 
            
            % was using this to get rid of duplicate fragments -- but we
            % can prune later after matching (this takes too long) 
            
%             min_dist = 1.1; 
%             % compare to all previously saved fragments using Hamming
%             % distance. If distance < overlap_threshold, then we don't keep
%             % the fragment because it's too similar to the current
%             % fragment. 
%             full_bw_list = dir(fullfile(PLATE_FOLDER_FULL_BW, '*.png')); 
%             tic
%             for bw_idx=1:compare_distances_up_to 
%                 if size(full_bw_list,1) == 0
%                     break
%                 end
%                 current_bw = imread(fullfile(PLATE_FOLDER_FULL_BW, full_bw_list(bw_idx).name)); 
%                 
%                 if ~any(current_bw(bbox))
%                 
%                 small_curr_bw = imresize(current_bw, 0.1); 
%                 small_curr_bw = logical(small_curr_bw); 
%                 
%                 dist = sum(sum(xor(small_curr_bw, small_full_bw))); 
%                 dist = dist/(sum(sum(small_full_bw)) + sum(sum(small_curr_bw))); 
%                 
%                 if dist < overlap_threshold
%                     figure();
%                     imshow(imfuse(small_curr_bw, small_full_bw)); 
%                     min_dist = dist; 
%                     break;
%                 end
%             end
%             toc
%             
%             if min_dist < overlap_threshold
%                 continue
%             end
                    
            imwrite(big_cc_grayscale, fullfile(PLATE_FOLDER, strcat(plate_name,num2str(save_num),'.png')));
            imwrite(full_bw, fullfile(PLATE_FOLDER_FULL_BW, strcat(plate_name,num2str(save_num),'.png')));
            % keeping track of how many fragments we've saved here 
            save_num = save_num + 1; 
        end
    end
end
