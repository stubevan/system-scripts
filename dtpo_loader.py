#!/usr/local/opt/python/bin/python2.7                                 #pylint: disable-msg=C0103
"""
    Load Specified file into DTPO with passed parameters
"""

from os.path import basename

import argparse
import logging
logging.basicConfig(level=logging.INFO)

import gntp.notifier

from appscript import app

SUCCESS = 0
DUPLICATE = 1
FAILED = 2

GROWL_FAIL = 'Failed Load'
GROWL_SUCCESS = 'Successful Load'
GROWL_APPLICATION = 'DTPO Loader'

class LoadError(Exception) :
    """ Exception raised while parsing lines in config files
    """
    def __init__(self, message) :
        self.message = message
        Exception.__init__(self)


def execute_import(database, source_file, document_name, group, tags) :
    """
        Now run the actual import into DTPO
    """

    assert database
    assert source_file
    assert document_name
    assert tags is not None
    assert tags is not None
    
    if group is '' :
        group = 'Inbox'
        
    ret_code = FAILED

    try :
        #   First see if the relevant database is open already
        dtpo_db_id = None
        dt = app(u'DEVONthink Pro')
        for dtpo_db in dt.databases.get() :
            if dtpo_db.path() == database :
                dtpo_db_id = dtpo_db.id()
                break
        if dtpo_db_id is None :
            dtpo_db = app(u'DEVONthink Pro').open_database(database)
            dtpo_db_id = dtpo_db.id()

    except AttributeError as attribute_error :
        message = "Couldn't open database {0}".format(database)
        raise LoadError(message)

    try :
        dtpo_group = app(u'DEVONthink Pro').create_location(
            group,
            in_=app.databases.ID(dtpo_db_id))
        # get the group to check that it's there
        dtpo_group_id = dtpo_group.id()           #pylint: disable-msg=W0612
    except AttributeError as attribute_error :
        message = "Failed access group {0} -> {1}".format(
            group, str(attribute_error))
        raise LoadError(message)

    try :
        doc = app(u'DEVONthink Pro').import_(
            source_file,
            name = document_name,
            to = dtpo_group)

        docid = doc.id()
    except AttributeError as attribute_error :
        message = "Failed import document {0} -> {1}".format(
            document_name, str(attribute_error))
        raise LoadError(message)

    try :
        app(u'DEVONthink Pro').databases.ID(
            dtpo_db_id).contents.ID(docid).unread.set(True)
        app(u'DEVONthink Pro').databases.ID(
            dtpo_db_id).contents.ID(docid).tags.set(tags)
        app(u'DEVONthink Pro').databases.ID(
            dtpo_db_id).contents.ID(docid).URL.set('')
        duplicate = app(u'DEVONthink Pro').databases.ID(
            dtpo_db_id).contents.ID(docid).number_of_duplicates.get()
        if int(duplicate) == 0 :
            ret_code = SUCCESS
        else:
            ret_code = DUPLICATE
    except AttributeError as attribute_error :
        message = "Failed set attributes {0} -> {1}".format(
            source_file, str(attribute_error))
        raise LoadError(message)

    return ret_code

def main() :
    """
    Get the command line arguments
    """
    p = argparse.ArgumentParser(description='DTPO Auto Load')
    p.add_argument('-d', '--database', dest='database', required=True,
                   metavar='DTPO Database',
                   help='Full path to DTPO database folder')
    p.add_argument('-s', '--source_file', dest='source_file', required=True,
                   metavar='Source File',
                   help='Path to file to be loaded - Document name is basename')
    p.add_argument('-g', '--group', dest='group', required=False, default='',
                   metavar='Destination Group',
                   help='Destination group - default is Inbox')
    p.add_argument('-t', '--tags', dest='tags', required=False, default='',
                   metavar='Document Tags',
                   help='Comma seperated list of Tags - default None')

    args = p.parse_args()

    assert args.database
    assert args.source_file
    
    # We have the arguments in a safe way
    
    document_name = basename(args.source_file)
    exit_message = None
    note_type = GROWL_FAIL
    exit_code = FAILED
    
    try :
        rc = execute_import(args.database, args.source_file,
                                   document_name, args.group, args.tags)
        if rc == SUCCESS :
            exit_message = "Successfully loaded -> "
        else :
            exit_message = "Duplicate load of -> "
            
        exit_message += document_name + " into " + args.group
        note_type = GROWL_SUCCESS
        exit_code = SUCCESS

    except LoadError as load_error :
        #    We failed ...
        exit_message = load_error.message
    except Exception as exception :
        #   Something horrible has occurred
        exit_message = args.source_file + " -> Unexpected exception: " + \
                  str(exception)

    # Let the world know what happend
    growl = gntp.notifier.GrowlNotifier(
        applicationName = GROWL_APPLICATION,
        notifications = [GROWL_SUCCESS, GROWL_FAIL],
        defaultNotifications = [GROWL_SUCCESS],)
    
    # Don't like doing this but gntp sets the default level to INFO
    logging.getLogger().setLevel(logging.WARNING)
    growl.register()
    
    growl.notify(
        noteType = note_type,
        title = GROWL_APPLICATION,
        description = exit_message,)

    return exit_code

if __name__ == '__main__':
    exit(main())
