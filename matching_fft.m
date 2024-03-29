clc; clear; close all;
% matching for the verification task

% matching with extra thing that keeps track of when each fragment was
% added

% addpath to SIFTFLOW 
addpath('/Users/bjmongol/Documents/ML/fragment_matching/SIFTflow/mexDiscreteFlow');
addpath('/Users/bjmongol/Documents/ML/fragment_matching/SIFTflow/mexDenseSIFT');
addpath('/Users/bjmongol/Documents/ML/fragment_matching/SIFTflow');

% keep scores for each fragment being run as a query
% 4 cells -- 
% 1) name of fragment 
% 2) name of plate 
% 3) full directory of the plate 
% 4) all matches with 
%   i) fragment name
%   ii) plate name
%   iii) full directory to image of fragment
%   iv) size distance (x axis) 
%   v) size distance (y axis)
%   vi) shape distance 
%   vii) siftflow distance 
%   viii) how many fragments we have searched through (useful for testing
%   robustness... just ignore this number!!!)

scores_new_as_query = {};  
rankings = {};

% list of old plates (for each fragment in each old plate we would like to
% run it as a query and search through fragments in all new plates) 
old_folders = dir(fullfile('DATA', 'OLD_SEGMENTED', 'fragment'));
idx = ismember({old_folders.name}, {'.', '..', '.DS_Store'});
old_plate_name_list = old_folders(~idx);
old_plate_name_list = {old_plate_name_list.name};
old_plate_name_list = transpose(old_plate_name_list);

% list of new plates (for each fragment in each old plate we would like to
% run it as a query and search through fragments in all new plates) 
% if we are running multiple 
new_folders = dir(fullfile('DATA', 'NEW_SEGMENTED'));
idx = ismember({new_folders.name}, {'.', '..', '.DS_Store'});
new_plate_name_list = new_folders(~idx);
new_plate_name_list = {new_plate_name_list.name};
new_plate_name_list = transpose(new_plate_name_list);

% iterate over new plates 
for new_plate_num=1:length(new_plate_name_list)
    % current new plate 
    new_plate_name = new_plate_name_list{new_plate_num};
    DATA_DIR = fullfile('DATA','NEW_SEGMENTED', new_plate_name);
    % 'matching' pairs are stored here
    RES_DIR = fullfile('RESULTS','matches');
    
    % list of all images on the current new plate 
    new_templates_list = dir(fullfile(DATA_DIR, '*.png')); 
    
    for new_image_ind=1:length(new_templates_list)
        total_num_fragments = 0; 
        new_im_name = new_templates_list(new_image_ind).name;
        
        % make a new entry for the template to store the matches that
        % we get 
        sze = size(scores_new_as_query); 
        num_queries = sze(1) + 1; %number of queries that we've run

        % process the new image
        template_im = rgb2gray(imread(fullfile(DATA_DIR, new_im_name)));
        template_bw = template_im > 0; 

        template_stats = regionprops(template_bw,'Centroid','Area','PixelIdxList','ConvexHull','Image','MajorAxisLength','MinorAxisLength','Orientation');

        template_correct_cc_ind=0;
        max_area = 0;
        for cc_ind=1:length(template_stats)
            if template_stats(cc_ind).Area>max_area
                template_correct_cc_ind = cc_ind;
                max_area = template_stats(cc_ind).Area;
            end
        end

        cropped_template_bw = template_bw;
        cropped_template_grayscale = template_im;

        if template_correct_cc_ind ~= 0
            cropped_template_bw = template_stats(template_correct_cc_ind).Image;

            [a,b]  = ind2sub(size(template_im),template_stats(template_correct_cc_ind).PixelIdxList);
            a2 = a - min(a) + 1; b2 = b - min(b) + 1;
            cropped_template_grayscale = uint8(zeros(size(cropped_template_bw)));
            M = length(a);
            for index=1:M
                cropped_template_grayscale(a2(index),b2(index)) =  template_im(a(index),b(index));
            end
        end


        % resize the new fragment so that it is on a similar scale to
        % the old fragment
        cropped_template_grayscale = imresize(cropped_template_grayscale,[size(cropped_template_grayscale,1)*1.4, ...
            size(cropped_template_grayscale,2)*1.4]);

        cropped_template_bw = imresize(cropped_template_bw,[size(cropped_template_bw,1)*1.4, ...
            size(cropped_template_bw,2)*1.4]);
        
        figure; 
        imshow(cropped_template_grayscale); 
        close all; 
        
        scores_new_as_query(num_queries,:) = {new_im_name, new_plate_name, fullfile(DATA_DIR,new_im_name), {}};
        for old_plate_num=1:length(old_plate_name_list)
            % current old plate 
            old_plate_name = old_plate_name_list{old_plate_num};

            OLD_SEG_DIR = fullfile('DATA', 'OLD_SEGMENTED', 'fragment', old_plate_name);
            
            fprintf('query %d/%d from %s to %s\n', new_image_ind, length(new_templates_list), new_plate_name, old_plate_name);

            % SIFT-flow parameters
            cellsize=[1,3];
            gridspacing=1;
            IsBoundary = true;

            SIFTflowpara.alpha=2*255;
            SIFTflowpara.d=40*255;
            SIFTflowpara.gamma=0.005*255;
            SIFTflowpara.nlevels=4;
            SIFTflowpara.wsize=2;
            SIFTflowpara.topwsize=10;
            SIFTflowpara.nTopIterations = 60;
            SIFTflowpara.nIterations= 30;

            %going over the old segmented templates
            % list of all old images on the current old plate 
            old_templates_list = dir(fullfile(OLD_SEG_DIR, '*.png'));
            for old_image_ind=1:length(old_templates_list)
                total_num_fragments = total_num_fragments + 1; 
                cur_cc_grayscale = imread(fullfile(OLD_SEG_DIR,old_templates_list(old_image_ind).name));
                if size(size(cur_cc_grayscale),2) == 3
                    cur_cc_grayscale = rgb2gray(cur_cc_grayscale);
                end
                
                % estimate transform amount
                tformEstimate = imregcorr(cur_cc_grayscale, cropped_template_grayscale, 'rigid');
                % rotate image (don't mess with scale) 
                cur_cc_rotated = imwarp(cur_cc_grayscale,tformEstimate);
                
                % size distance
                % this is scale test part
                size1_distance = abs(size(cropped_template_grayscale,1) - size(cur_cc_rotated,1));
                size2_distance = abs(size(cropped_template_grayscale,2) - size(cur_cc_rotated,2));

                if (size1_distance > 500) % 300
                    continue
                end

                if (size2_distance > 500) %300
                    continue
                end

                cur_cc_bw =  cur_cc_rotated > 0;
                %shape test
                cur_cc_bw = imresize(cur_cc_bw,size(cropped_template_grayscale));
                cur_cc_rotated = imresize(cur_cc_rotated, size(cropped_template_grayscale));

                cur_distance = sum(sum(abs(cropped_template_bw - cur_cc_bw)));
                norm_constant = size(cropped_template_bw,1) * size(cropped_template_bw,2);
                shape_distance = cur_distance/norm_constant;

                if shape_distance > 0.3 % 0.3
                    continue
                end

                % sift flow test, K is the size of our image when we're
                % doing the SIFT-flow test. It was found that 100x100 pixels
                % gives reasonable results and is also very fast to compute
                % K = 512;
                % K = 250;
                K = 100; 

                cropped_template_grayscale2 = double(imresize(cropped_template_grayscale,[K,K]));
                cur_cc_grayscale2 = double(imresize(cur_cc_rotated,[K,K]));

                %         cropped_template_grayscale2 = double(cropped_template_grayscale);
                %         cur_cc_grayscale2 = double(cur_cc_grayscale);
                %
                sift1 = mexDenseSIFT(cropped_template_grayscale2,cellsize,gridspacing,IsBoundary);
                sift2 = mexDenseSIFT(cur_cc_grayscale2,cellsize,gridspacing,IsBoundary);

                % calculate sift from old image to new image
                tic;[vx,vy,energylist]=SIFTflowc2f(sift2,sift1,SIFTflowpara);toc

                warpI2=warpImage(cur_cc_grayscale2,vx,vy);
                warpI=warpImage(cropped_template_grayscale2,vx,vy);
                %             figure;imshow(uint8(warpI2));

                g = energylist.data;
                siftflow_distance  = min(g);

%                 montage_image = zeros([size(cur_cc_grayscale2),1,3]);
%                 montage_image(:,:,:,1) = cropped_template_grayscale2;
%                 montage_image(:,:,:,2) = cur_cc_grayscale2;
%                 montage_image(:,:,:,3) = warpI2;
%                 f = figure;
%                 montage_image = uint8(montage_image);
%                 montage(montage_image,'size', [1,3]);
% 
%                 title(sprintf('size1 dist: %f, size2 dist: %f, shape dist: %f, siftflow dist: %f',size1_distance, size2_distance, shape_distance, siftflow_distance));
                % saveas(f,fullfile(RES_DIR,strcat(new_im_name(1:end-4),sprintf('_%d_.png',old_image_ind))),'png');

                % save the scores
                % keep scores for each fragment being run as a query
                % 4 cells -- 
                % 1) name of fragment 
                % 2) name of plate 
                % 3) full directory of the plate 
                % 4) all matches with 
                %   i) name
                %   ii) plate
                %   iii) full directory
                %   iv) size distance 
                %   v) shape distance 
                %   vi) siftflow distance 

                % query number
                query_number = size(scores_new_as_query,1);

                % find which match number this is and append 
                match_number = size(scores_new_as_query{query_number,4},1) + 1;

                % also keep track of fragment number -- when it was
                % searched
                scores_new_as_query{query_number,4}(match_number,:) = ...
                                                    {old_templates_list(old_image_ind).name,...
                                                    old_plate_name,...
                                                    fullfile(OLD_SEG_DIR,old_templates_list(old_image_ind).name),...
                                                    size1_distance, size2_distance,...
                                                    shape_distance,...
                                                    siftflow_distance,...
                                                    total_num_fragments,...
                                                    rotation_amount};

                % we sort by the siftflow distance
                scores_new_as_query{query_number,4} = sortrows(scores_new_as_query{query_number,4},7);

                % save the results
                save('scores_fft.mat', 'scores_new_as_query');

                close all;

            end         
        end
    end
end