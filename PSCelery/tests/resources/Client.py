#!/usr/bin/env python3
from celery_conf import app
from celery import signature

if __name__ == '__main__':
   task = app.send_task('wf_worker.celery_app.respond', ('meow', ), queue='workflow',
                        link=signature('wf_worker.celery_app.callback', app=app, queue='workflow'))
   result = task.wait()

   print(result)