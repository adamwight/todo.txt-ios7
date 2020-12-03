/**
 * This file is part of Todo.txt, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011-2013 Todo.txt contributors (http://todotxt.com)
 *
 * Dual-licensed under the GNU General Public License and the MIT License
 *
 * @license GNU General Public License http://www.gnu.org/licenses/gpl.html
 *
 * Todo.txt is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any
 * later version.
 *
 * Todo.txt is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with Todo.txt.  If not, see
 * <http://www.gnu.org/licenses/>.
 *
 *
 * @license The MIT License http://www.opensource.org/licenses/mit-license.php
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "TodoTxtAppDelegate.h"
#import "FilterViewController.h"
#import "TaskFilterTarget.h"
#import "TaskBag.h"
#import "TaskBagFactory.h"
#import "AsyncTask.h"
#import "Network.h"
#import "LocalFileTaskRepository.h"
#import "Util.h"
#import "Reachability.h"
#import "SJNotificationViewController.h"

@interface TodoTxtAppDelegate ()

@property (nonatomic, weak) TasksViewController *viewController;
@property (nonatomic, weak) UINavigationController *contentNavController;
@property (nonatomic, strong) id<TaskBag> taskBag;
@property (nonatomic, strong) NSDate *lastSync;

@end

@implementation TodoTxtAppDelegate

#pragma mark -
#pragma mark Application lifecycle

- (void) presentMainViewController {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)displayNotification:(NSString *)message {
    // Performing UI operations, so run on the main thread
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        SJNotificationViewController *notificationController = [[SJNotificationViewController alloc] initWithNibName:@"SJNotificationViewController" bundle:nil];
        [notificationController setParentView:self.contentNavController.view];
        [notificationController setNotificationTitle:message];
        
        [notificationController setNotificationDuration:2000];
        [notificationController setBackgroundColor:[UIColor colorWithRed:0
                                                                   green:0
                                                                    blue:0 
                                                                   alpha:0.6f]];
        
        [notificationController show];
    }];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.taskBag = [TaskBagFactory getTaskBag];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
   
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"YES", @"date_new_tasks_preference",
								 @"/todo", @"file_location_preference",
								 @"none", @"badgeCount_preference", nil];
    [defaults registerDefaults:appDefaults];

    UIViewController *rootViewController = self.window.rootViewController;
    
    // Get the nav controller on whose active view notification toasts should show
    self.contentNavController = (UINavigationController *)rootViewController;
    
    // Connect the FilterViewController to its filtering target.
    // The FilterViewController and its target are the two VCs in a split VC;
    // the FilterViewController is the master view controller, and its target is the detail view controller.
    // The detail nav controller is the one on which toasts should show, at index 1 on iPad.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)rootViewController;
        NSArray *viewControllers = [splitViewController viewControllers];
        splitViewController.delegate = (id<UISplitViewControllerDelegate>)[(UINavigationController *)viewControllers[1] topViewController];
        
        [(FilterViewController *)[(UINavigationController *)viewControllers[0] topViewController]
         setFilterTarget:(id<TaskFilterTarget>)[(UINavigationController *)viewControllers[1] topViewController]];
        self.contentNavController = viewControllers[1];
    }
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName: kTodoChangedNotification object: nil];
	
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

- (void)dealloc {
    self.viewController = nil;
}


@end
