# 1. Use an official Python runtime as a parent image
FROM python:3.9-slim

# 2. Set the working directory inside the container
WORKDIR /code

# 3. Copy the requirements file into the container
COPY ./requirements.txt /code/requirements.txt

# 4. Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# 5. Copy the app directory into the container
COPY ./app /code/app

# 6. Expose the port the app runs on
EXPOSE 8000

# 7. Define the command to run your app using uvicorn
# This will run the 'app' instance from the 'main.py' file
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]