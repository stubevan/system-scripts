#!/usr/bin/env python                                 #pylint: disable-msg=C0103

'''
    Script to prune a tarsnap archive according to preset parameters
'''

import sys
from datetime import datetime
import argparse
import subprocess
import logging

def form_prune_list(archive_list,
                    archive_name,
                    hours_to_keep,
                    days_to_keep,
                    months_to_keep,
                    time_now = datetime.now()) :
    '''
	archive_list - entries of the form YYYYMMDD.HHMM-ArchiveName
	archiveName - anything which doesn't match will be ignored
	hours_to_keep
	days_to_keep
	months_to_keep
	time_now - only set for testing purposes

        method works by starting from the oldest
    '''

    return_list = []
    keep_list = []
    months_got = {}
    days_got = {}
    hours_got = {}

    logging.info('form_prune_list: archive_name: %s,  months_to_keep %d, '
                 "days_to_keep: %d, hours_to_keep %d, time_now: %s", \
                    archive_name, months_to_keep, days_to_keep, hours_to_keep, \
                    str(time_now))

    archive_list.sort(reverse=True)

    for archive_to_check in archive_list :
        
        # check that it's a valid archive
        if archive_to_check[len(archive_to_check) - len(archive_name):] \
            != archive_name :
            continue

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
        # OK It's not strictly a month but its good enough
        time_delta_months = time_delta_days // 28
            
        logging.debug("Differences months: %d , days: %d, hours: %d", \
                time_delta_months, time_delta_days, time_delta_hours)
            
            # Does it fall within the months boundary
        if int(time_delta_months) < int(months_to_keep):
            # yes - check to see whether this month already covered
            if archive_month not in months_got :
                months_got[archive_month] = True

                logging.debug("Saving %s on month", archive_to_check)
                keep_list.append(archive_to_check)
                continue
                            
            # Does it fall within the days boundary
            if int(time_delta_days) < int(days_to_keep) :
                if archive_day not in days_got :
                    days_got[archive_day] = True
                    keep_list.append(archive_to_check)
                    logging.debug("Saving %s on days", archive_to_check)
                    continue
                    
            # Does it fall within the hours boundary
            if int(time_delta_hours) < int(hours_to_keep):
                if archive_hour not in hours_got :
                    hours_got[archive_hour] = True
                    keep_list.append(archive_to_check)
                    logging.debug("Saving %s on hours", archive_to_check)
                    continue
                            
            # at this point nobody wants us :(
            logging.debug("Deleting: %s ", archive_to_check)
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
    p.add_argument('-A', '--archive_name', dest='archive_name', required=True,
                   metavar='Archive Name',
                   help='[REQUIRED] The Archive We want to Prune')
    p.add_argument('-d', '--debug', dest='debug', required=False,
                   action="store_true",
                   help='[OPTIONAL] Debug')
    
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
    
    # get the archive
    tarsnap_command = args.tarsnap_args + " --list-archives"
    logging.debug('getting archives: %s', tarsnap_command)
    sub = subprocess.Popen(tarsnap_command, shell=True,
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
    
    error_string = sub.stderr.read()
    if error_string != "" :
        # We've had a probem
        logging.fatal("Listing of tarsnap archives failed: %s ", error_string)
        sys.exit(1)
        
    archive_string = sub.stdout.read()
    
    archive_list = archive_string.split('\n')
    
    archives_to_delete = form_prune_list(
        archive_list, args.archive_name, hours_to_keep = args.hours_to_keep,
        days_to_keep = args.days_to_keep, months_to_keep = args.months_to_keep)
    
    # we have the archive list - lets do the damage
    for archive_to_delete in archives_to_delete:
        tarsnap_command = args.tarsnap_args + " -d -f " + archive_to_delete
            
        logging.info("Pruning -> %s", archive_to_delete)
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
