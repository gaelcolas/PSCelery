BROKER_URL = 'amqp://guest@localhost//'
CELERY_RESULT_BACKEND = 'rpc://guest@localhost//'

CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TIMEZONE = 'Europe/London'
CELERY_ENABLE_UTC = True
