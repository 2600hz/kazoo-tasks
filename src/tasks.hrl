-ifndef(KZ_TASKS_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_tasks/include/tasks.hrl").

-define(APP, 'tasks').
-define(APP_NAME, <<"tasks">>).
-define(APP_VERSION, <<"4.0.0">> ).
-define(CONFIG_CAT, ?APP_NAME).

-define(WORKER_TASK_FAILED, <<"applier crashed">>).
-define(WORKER_TASK_MAYBE_OK, <<"internal">>).
-define(OUTPUT_CSV_HEADER_ERROR, <<"error">>).

-define(START_WORKER_RPC_CALL_TIMEOUT_US, 10 * ?MICROSECONDS_IN_SECOND).
-define(TASKS_RA, 'task').
-define(TASKS_SUP, 'tasks_sup').

-define(KZ_TASKS_HRL, 'true').

-type task_worker() :: 'kz_tasks_scheduler' | 'tasks_listener' | 'kz_tasks_trigger'
                     | 'kt_port_request_crawler' | 'kt_number_crawler' | 'kz_account_crawler'
                     | 'kz_notify_resend' | 'kt_compaction_reporter'.

-define(TASK_WORKERS, ['kz_tasks_scheduler',
                       'tasks_listener',
                       'kz_tasks_trigger',
                       'kt_port_request_crawler',
                       'kt_number_crawler',
                       'kz_account_crawler',
                       'kz_notify_resend',
                       'kt_compaction_reporter'
                      ]).

-endif.
