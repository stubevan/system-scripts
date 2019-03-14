#!/usr/bin/env python                                 #pylint: disable-msg=C0103

'''
    Script to prune a tarsnap archive according to preset parameters
'''

import sys
from datetime import datetime
import argparse
import subprocess
import logging

def cmp_archives(archive1, archive2) :
    
    try :
        date1 = int(archive1[:8])
        time1 = int(archive1[10:13])
        date2 = int(archive2[:8])
        time2 = int(archive2[10:13])
    except ValueError :
        return 0
    
    if date1 < date2 :
        return -1
    elif date1 > date2 :
        return 1
    
    # dates are equal - do the same for times but this time less is more
    if time1 < time2 :
        return 1
    elif time1 > time2 :
        return -1
    
    return 0


def calculate_time_deltas(archive_to_check, time_now) :
    # extract the date components and then find the difference
    archive_year = int(archive_to_check[:4])
    archive_month = int(archive_to_check[4:6])
    archive_day = int(archive_to_check[6:8])
    archive_hour = int(archive_to_check[9:11])
            
    archive_date = datetime(archive_year, archive_month, archive_day,
        archive_hour)
        
    time_delta = time_now - archive_date
    time_delta_sec = time_delta.total_seconds()
            
    time_delta_hours = time_delta_sec // 3600
    time_delta_days = time_delta_hours // 24
        
    time_delta_months = (time_now.year * 12 + time_now.month) - \
        (archive_year * 12 + archive_month)
            
    logging.debug("Differences months: %d , days: %d, hours: %d", \
        time_delta_months, time_delta_days, time_delta_hours)
        
    return time_delta_months, time_delta_days, time_delta_hours, \
           archive_month, archive_day, archive_hour


def form_prune_list(archive_list,
                    hours_to_keep,
                    days_to_keep,
                    months_to_keep,
                    time_now = datetime.now()) :
    '''
	archive_list - entries of the form YYYYMMDD.HHMM-ArchiveName
	             - Anything that doesnt match will be ignored
	hours_to_keep
	days_to_keep
	months_to_keep
	time_now - only set for testing purposes
	20160618.0300

        If there is more than one match in a given criteria then keep the newest

    '''

    return_list = []

    logging.info('form_prune_list: months_to_keep %d, '
                 "days_to_keep: %d, hours_to_keep %d, time_now: %s", \
                    months_to_keep, days_to_keep, hours_to_keep,  str(time_now))

    # Want to start with the newest
    archive_list.sort(cmp_archives) 
    last_hour_kept = 0
    last_day_kept = 0
    last_month_kept = 0

    for archive_to_check in archive_list :
        try :
            time_delta_months, time_delta_days, time_delta_hours, \
                archive_month, archive_day, archive_hour = \
                    calculate_time_deltas(archive_to_check, time_now)
        except ValueError :
            logging.warning('form_prune_list: unusual archive %s -> IGNORING', \
                            archive_to_check)
            continue

        logging.debug("Archive -> %s, Months -> %d, Days -> %d, Hours -> %d", 
		    archive_to_check, time_delta_months,
                    time_delta_days, time_delta_hours)

        saved = False
        # Does it fall within the hours boundary
        if time_delta_hours < hours_to_keep and \
                archive_hour != last_hour_kept :
            saved = True
            last_hour_kept = archive_hour
            logging.info("Keeping -> %s on hours", archive_to_check)

        # Does it fall within the days boundary
        elif time_delta_days < days_to_keep and \
                archive_day != last_day_kept :
            last_day_kept = archive_day
            if not saved :
                saved = True
                logging.info("Keeping -> %s on days", archive_to_check)
                
        # Does it fall within the months boundary
        elif time_delta_months < months_to_keep and \
                archive_month != last_month_kept :
            last_month_kept = archive_month
            if not saved :
                saved = True
                logging.info("Keeping -> %s on months", archive_to_check)
                            
        if not saved :               
            # at this point nobody wants us :(
            logging.debug("Pruning -> %s ", archive_to_check)
            return_list.append(archive_to_check)

    return return_list                                  


def main() :
    """
    Get the command line arguments
    """
    
    p = argparse.ArgumentParser(description='Tarsnap prune')
    p.add_argument('-H', '--hours_to_keep', dest='hours_to_keep', required=True,
                   metavar='Days To Keep', type=int,
                   help='[REQUIRED] Hours of Archive to Keep')
    p.add_argument('-D', '--days_to_keep', dest='days_to_keep', required=True,
                   metavar='Days To Keep', type=int,
                   help='[REQUIRED] Days of Archive to Keep')
    p.add_argument('-M', '--months_to_keep', dest='months_to_keep',
                   required=True, metavar='months To Keep', type=int,
                   help='[REQUIRED] Months of Archive to Keep')
    p.add_argument('-t', '--tarsnap_args', dest='tarsnap_args', required=True,
                   metavar='Tarsnap Args',
                   help='[REQUIRED] Default arguments to tarsnap')
    p.add_argument('-n', '--dryrun', dest='dryrun', required=False,
                   action="store_true",
                   help='[OPTIONAL] Debug')
    p.add_argument('-d', '--debug', dest='debug', required=False,
                   action="store_true",
                   help='[OPTIONAL] Debug')
    p.add_argument('-T', '--test_file', dest='testfile', required=False,
               help='[OPTIONAL] Test - file containing tarsnap output')
    
    args = p.parse_args()

    assert args.hours_to_keep
    assert args.days_to_keep
    assert args.months_to_keep
    assert args.tarsnap_args
    
    loglevel = logging.INFO
    if args.debug :
        loglevel = logging.DEBUG
    
    logging.basicConfig (
        format = "%(levelname)-10s %(asctime)s %(message)s",
        level = loglevel)
    
    # Lets see if we're testing
    if args.testfile :
        logging.info("TESTING - Reading archive from -> %s", args.testfile)
        with open(args.testfile) as f:
            archive_list = [line.rstrip() for line in f]
    else :
        if args.dryrun :
            logging.info("Dry Run - no archives will be deleted")
            
        # get the archive list from tarsnap
        tarsnap_command = args.tarsnap_args + " --list-archives"
        logging.info('getting archives: %s', tarsnap_command)
        sub = subprocess.Popen(tarsnap_command, shell=True,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE)
        
        if sub.returncode :
            error_string = sub.stderr.read()
            logging.fatal("Listing of tarsnap archives failed: %s ",
                          error_string)
            sys.exit(1)
            
        archive_string = sub.stdout.read()
        
        archive_list = archive_string.split('\n')
    
    archives_to_delete = form_prune_list(
        archive_list, hours_to_keep = args.hours_to_keep,
        days_to_keep = args.days_to_keep, months_to_keep = args.months_to_keep)
    
    # we have the archive list - lets do the damage
    for archive_to_delete in archives_to_delete:
        tarsnap_command = args.tarsnap_args + " -d -f " + archive_to_delete
            
        logging.info("Deleting tarsnap archive -> %s", archive_to_delete)
        
        if not args.testfile and not args.dryrun :
            logging.debug("Tarsnap command -> %s", tarsnap_command)
            sub = subprocess.Popen(tarsnap_command, shell=True,
                                  stderr=subprocess.PIPE,
                                  stdout=open('/dev/null'))
            
            error_string = sub.stderr.read()
            if error_string != "" :
                # We've had a probem
                logging.fatal("Deletion of tarsnap archive %s failed: %s ",
                              archive_to_delete, error_string)
                sys.exit(1)
        
if __name__ == '__main__':
    exit(main())
