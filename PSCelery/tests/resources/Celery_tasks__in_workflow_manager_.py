@app.task
def callback(input):
   assert isinstance(input, str)
   rv = ("<Callback(): Received input: {}>".format(input))
   time.sleep(10)
   print('PRINT -{}-'.format(rv))

@app.task
def respond(input):
   assert isinstance(input, str)
   rv = "<Respond(): Received input: {}>".format(input)
   time.sleep(10)
   print('PRINT -{}-'.format(rv))
   return rv