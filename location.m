% create folders and save all fragments 1) fused with its parent and 2)
% just the plate itself -- this shows us the location of the fragments
% must first run statistics.m and have a stats.mat file with the correct
% matches in it 

RES_FOLDER = fullfile('RESULTS','location'); 

load('stats.mat'); 

for i=1:size(stats,1)
    % create directory to save results for each new image
    new_img_name = stats{i,1}(1:end-4); 
    SPECIFIC_RESULTS_FOLDER = fullfile(RES_FOLDER, new_img_name); 
    

    if exist(SPECIFIC_RESULTS_FOLDER, 'dir') ~= 7
        mkdir(SPECIFIC_RESULTS_FOLDER);
    end
    
    % save the new image of fragment 
    new_img = imread(stats{i,3});
    imwrite(new_img, fullfile(SPECIFIC_RESULTS_FOLDER, stats{i,1})); 
    
    for j=1:size(stats{i,4})
        % save the old image of the fragment for each match
        plate_name = stats{i,4}{j,2};
        % check if we have matches from the exact same plate
        if size(dir(fullfile(SPECIFIC_RESULTS_FOLDER,strcat(plate_name,'_result.png')))) > 0
            continue
        end
        plate_img = imread(fullfile('DATA', 'OLD_UNSEGMENTED', 'plates' ,strcat(plate_name,'.jpg')));
        imwrite(plate_img, fullfile(SPECIFIC_RESULTS_FOLDER, strcat(plate_name,'.jpg')));
        
        % for each result, overlay the mask on the PAM and save the result
        mask = imread(fullfile('DATA', 'OLD_SEGMENTED','plate',plate_name,stats{i,4}{j,1}));
        overlaid = cat(3, plate_img, mask + plate_img, plate_img);
        imwrite(overlaid, fullfile(SPECIFIC_RESULTS_FOLDER, strcat(plate_name,'_result.png')));
    end
end