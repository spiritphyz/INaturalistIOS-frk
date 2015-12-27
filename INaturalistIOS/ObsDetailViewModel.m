//
//  ObsDetailViewModel.m
//  iNaturalist
//
//  Created by Alex Shepard on 11/17/15.
//  Copyright © 2015 iNaturalist. All rights reserved.
//

#import <SDWebImage/UIImageView+WebCache.h>
#import <UIColor-HTMLColors/UIColor+HTMLColors.h>
#import <FontAwesomeKit/FAKIonIcons.h>

#import "ObsDetailViewModel.h"
#import "Observation.h"
#import "User.h"
#import "Taxon.h"
#import "TaxonPhoto.h"
#import "ImageStore.h"
#import "ObservationPhoto.h"
#import "PhotosPageControlCell.h"
#import "DisclosureCell.h"
#import "SubtitleDisclosureCell.h"
#import "NSURL+INaturalist.h"
#import "Analytics.h"
#import "FAKINaturalist.h"
#import "ObsDetailInfoViewModel.h"
#import "ObsDetailActivityViewModel.h"
#import "ObsDetailFavesViewModel.h"
#import "UIColor+INaturalist.h"
#import "ObsDetailSelectorHeaderView.h"
#import "ObsDetailTaxonCell.h"

@interface ObsDetailViewModel ()

@property NSInteger viewingPhoto;

@end

@implementation ObsDetailViewModel

- (instancetype)init {
    if (self = [super init]) {
    }
    
    return self;
}

#pragma mark - UITableView datasource/delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // hack
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 3;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // first four rows of section 0 are shared among all view models
    if (indexPath.section == 0) {
        if (indexPath.item == 0) {
            return [self userDateCellForTableView:tableView];
        } else if (indexPath.item == 1) {
            return [self photoCellForTableView:tableView];
        } else if (indexPath.item == 2) {
            return [self taxonCellForTableView:tableView indexPath:indexPath];
        }
    } else {
        return nil;
    }
}

- (UITableViewCell *)userDateCellForTableView:(UITableView *)tableView {
    DisclosureCell *cell = [tableView dequeueReusableCellWithIdentifier:@"disclosure"];
    
    User *user = [[User objectsWithPredicate:[NSPredicate predicateWithFormat:@"recordID == %d", self.observation.userID.integerValue]] firstObject];
    // what if the user's not logged in?
    if (user) {
        NSURL *userIconUrl = [NSURL URLWithString:[user userIconURL]];
        if (userIconUrl) {
            [cell.cellImageView sd_setImageWithURL:userIconUrl];
            cell.cellImageView.layer.cornerRadius = 27.0 / 2;
            cell.cellImageView.clipsToBounds = YES;
        }
        cell.titleLabel.text = user.login;
    } else {
        cell.titleLabel.text = @"Nobody";
    }
    cell.secondaryLabel.text = self.observation.observedOnShortString;
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (UITableViewCell *)photoCellForTableView:(UITableView *)tableView {
    // photos
    PhotosPageControlCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photos"];
    
    if (self.observation.observationPhotos.count > 0) {
        ObservationPhoto *op = self.observation.sortedObservationPhotos[self.viewingPhoto];
        if (op.photoKey) {
            cell.iv.image = [[ImageStore sharedImageStore] find:op.photoKey forSize:ImageStoreLargeSize];
        } else {
            [cell.iv sd_setImageWithURL:op.largePhotoUrl];
        }
    }
    
    if (self.observation.observationPhotos.count > 1) {
        cell.pageControl.hidden = NO;
        cell.pageControl.numberOfPages = self.observation.observationPhotos.count;
        cell.pageControl.currentPage = self.viewingPhoto;
        [cell.pageControl addTarget:self
                             action:@selector(pageControlChanged:)
                   forControlEvents:UIControlEventValueChanged];
        
        
        UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                         action:@selector(swiped:)];
        swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
        [cell addGestureRecognizer:swipeRight];
        
        UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(swiped:)];
        swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
        [cell addGestureRecognizer:swipeLeft];
    } else {
        cell.pageControl.hidden = YES;
    }
    
    cell.captiveContainer.hidden = !self.observation.captive.boolValue;
    [cell.captiveInfoButton addTarget:self
                               action:@selector(captiveInfoPressed)
                     forControlEvents:UIControlEventTouchUpInside];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (UITableViewCell *)taxonCellForTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    ObsDetailTaxonCell *cell = [tableView dequeueReusableCellWithIdentifier:@"taxon"];

    
    Taxon *taxon = self.observation.taxon;
    if (!taxon && self.observation.taxonID && self.observation.taxonID.integerValue != 0) {
        taxon = [[Taxon objectsWithPredicate:[NSPredicate predicateWithFormat:@"recordID == %ld", self.observation.taxonID.integerValue]] firstObject];
    }

    cell.taxonNameLabel.textColor = [UIColor blackColor];

    if (taxon) {
        cell.taxonNameLabel.text = taxon.defaultName;
        
        if ([taxon.isIconic boolValue]) {
            cell.taxonImageView.image = [[ImageStore sharedImageStore] iconicTaxonImageForName:taxon.iconicTaxonName];
        } else if (taxon.taxonPhotos.count > 0) {
            TaxonPhoto *tp = taxon.taxonPhotos.firstObject;
            [cell.taxonImageView sd_setImageWithURL:[NSURL URLWithString:tp.thumbURL]];
        } else {
            cell.taxonImageView.image = [[ImageStore sharedImageStore] iconicTaxonImageForName:taxon.iconicTaxonName];
        }
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        FAKIcon *question = [FAKINaturalist speciesUnknownIconWithSize:44];
        [question addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithHexString:@"#777777"]];
        cell.taxonImageView.image = [question imageWithSize:CGSizeMake(44, 44)];
        
        if (self.observation.speciesGuess) {
            cell.taxonNameLabel.text = self.observation.speciesGuess;
        } else {
            cell.taxonNameLabel.text = NSLocalizedString(@"Something...", nil);
        }
    }
    
    if (!taxon.fullyLoaded) {
        // fetch complete taxon
        if ([[[RKClient sharedClient] reachabilityObserver] isNetworkReachable]) {
            
            
            NSString *resource = [NSString stringWithFormat:@"/taxa/%ld.json", (long)taxon.recordID.integerValue];
            
            __weak typeof(self) weakSelf = self;
            RKObjectLoaderDidLoadObjectBlock taxonLoadedBlock = ^(id object) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                
                Taxon *loadedTaxon = (Taxon *)object;
                loadedTaxon.syncedAt = [NSDate date];
                
                // save into core data
                NSError *saveError = nil;
                [[[RKObjectManager sharedManager] objectStore] save:&saveError];
                if (saveError) {
                    NSString *errMsg = [NSString stringWithFormat:@"Taxon Save Error: %@",
                                        saveError.localizedDescription];
                    [[Analytics sharedClient] debugLog:errMsg];
                    return;
                }
                
                // fetch the taxon and set it on the observation
                NSPredicate *taxonByIDPredicate = [NSPredicate predicateWithFormat:@"recordID = %ld", (long)taxon.recordID];
                Taxon *t = [Taxon objectWithPredicate:taxonByIDPredicate];
                strongSelf.observation.taxon = t;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [tableView reloadRowsAtIndexPaths:@[ indexPath ]
                                     withRowAnimation:UITableViewRowAnimationNone];
                });
                
            };
            
            [[Analytics sharedClient] debugLog:@"Network - Load a partially loaded taxon"];
            [[[RKObjectManager sharedManager] mappingProvider] setMapping:[Taxon mapping] forKeyPath:@""];
            [[RKObjectManager sharedManager] loadObjectsAtResourcePath:resource
                                                            usingBlock:^(RKObjectLoader *loader) {
                                                                loader.onDidLoadObject = taxonLoadedBlock;
                                                                
                                                                loader.onDidFailWithError = ^(NSError *error) {
                                                                    
                                                                };
                                                                loader.onDidFailLoadWithError = ^(NSError *error) {
                                                                    
                                                                };
                                                                loader.onDidLoadResponse = ^(RKResponse *response) {
                                                                    
                                                                };
                                                            }];
            
        } else {
            NSLog(@"no network, ignore");
        }
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return nil;
    } else if (section == 1) {
        ObsDetailSelectorHeaderView *selector = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"selectorHeader"];
        
        [selector.infoButton addTarget:self
                                action:@selector(selectedInfo:)
                      forControlEvents:UIControlEventTouchUpInside];
        
        [selector.activityButton addTarget:self
                                    action:@selector(selectedActivity:)
                          forControlEvents:UIControlEventTouchUpInside];
        
        // only show the activity count if there's unviewed activity on this obs
        if (self.observation.hasUnviewedActivity.boolValue) {
            selector.activityButton.count = self.observation.sortedActivity.count;
        } else {
            selector.activityButton.count = 0;
        }
        
        [selector.favesButton addTarget:self
                                 action:@selector(selectedFaves:)
                       forControlEvents:UIControlEventTouchUpInside];
        // don't show faves count for now
        selector.favesButton.count = 0;
        
        if (self.sectionType == ObsDetailSectionInfo) {
            selector.infoButton.enabled = NO;
        } else if (self.sectionType == ObsDetailSectionActivity) {
            selector.activityButton.enabled = NO;
        } else if (self.sectionType == ObsDetailSectionFaves) {
            selector.favesButton.enabled = NO;
        }

        return selector;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.item == 0) {
            // user
            return 44;
        } else if (indexPath.item == 1) {
            return 200;
        } else if (indexPath.item == 2) {
            return 44;
        }
    }
    
    return CGFLOAT_MIN;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return CGFLOAT_MIN;
    } else if (section == 1) {
        return 69.0f;
    }
    return CGFLOAT_MIN;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.item == 0) {
            // do nothing
        } else if (indexPath.item == 1) {
            // photos segue
            [self.delegate inat_performSegueWithIdentifier:@"photos" sender:@(self.viewingPhoto)];
        } else if (indexPath.item == 2) {
            // taxa segue
            if (self.observation.taxon) {
                [self.delegate inat_performSegueWithIdentifier:@"taxon" sender:self.observation.taxon];
            } else if (self.observation.taxonID) {
                Taxon *t = [[Taxon objectsWithPredicate:[NSPredicate predicateWithFormat:@"recordID == %ld", self.observation.taxonID.integerValue]] firstObject];
                [self.delegate inat_performSegueWithIdentifier:@"taxon" sender:t];
            }
        }
    }
}

#pragma mark - UITableView helpers


#pragma mark - uicontrol events

- (void)pageControlChanged:(UIPageControl *)pageControl {
    self.viewingPhoto = pageControl.currentPage;
    
    NSIndexPath *photoIp = [NSIndexPath indexPathForItem:1 inSection:0];
    [self.delegate reloadRowAtIndexPath:photoIp];
}

- (void)captiveInfoPressed {
    NSString *captiveTitle = NSLocalizedString(@"What does captive / cultivated mean?", @"title for alert explaining what captive means");
    NSString *captiveMsg = NSLocalizedString(@"Captive / cultivated means that the organism exists where it was observed because humans intended it to be there. iNaturalist is about observing wild organisms, and our scientific data partners are not interested in observations of pets, gardens, or animals in zoos.", @"message explaining what captive / cultivated means for iNaturalist");
    
    [[[UIAlertView alloc] initWithTitle:captiveTitle
                                message:captiveMsg
                               delegate:nil
                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                      otherButtonTitles:nil] show];
}

#pragma mark - gestures

- (void)swiped:(UISwipeGestureRecognizer *)gesture {
    NSIndexPath *photoIp = [NSIndexPath indexPathForItem:1 inSection:0];
    
    if (gesture.direction == UISwipeGestureRecognizerDirectionRight) {
        // swiping backward
        // swiping forward
        if (self.viewingPhoto == 0) {
            // do nothing
        } else {
            self.viewingPhoto--;
            [self.delegate reloadRowAtIndexPath:photoIp];
        }

    } else if (gesture.direction == UISwipeGestureRecognizerDirectionLeft) {
        // swiping forward
        if (self.viewingPhoto + 1 == self.observation.observationPhotos.count) {
            // do nothing
        } else {
            self.viewingPhoto++;
            [self.delegate reloadRowAtIndexPath:photoIp];
        }
    }
}

- (ObsDetailSection)sectionType {
    return ObsDetailSectionNone;
}


- (void)selectedInfo:(UIButton *)button {
    [self.delegate selectedSection:ObsDetailSectionInfo];
}

- (void)selectedActivity:(UIButton *)button {
    [self.delegate selectedSection:ObsDetailSectionActivity];
}

- (void)selectedFaves:(UIButton *)button {
    [self.delegate selectedSection:ObsDetailSectionFaves];
}


@end