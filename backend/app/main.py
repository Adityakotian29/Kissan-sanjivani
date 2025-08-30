import io
import os
import base64
import numpy as np
import tensorflow as tf
import cv2
from fastapi import FastAPI, UploadFile, File
from PIL import Image
import google.generativeai as genai
from dotenv import load_dotenv

# --- INITIALIZATION ---

# Load environment variables from .env file
load_dotenv()

# Initialize the FastAPI app
app = FastAPI(title="Rice Disease Detection and Explanation API")

# Load the trained deep learning model
MODEL_PATH = "app/rice_disease_model.h5"
model = tf.keras.models.load_model(MODEL_PATH)

# Configure the Generative AI model with the API key
try:
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
except Exception as e:
    print(f"Warning: Could not configure Generative AI. Explanations will not be available. Error: {e}")


CLASS_NAMES = ['Bacterialblight', 'Blast', 'Brownspot', 'Healthy', 'Tungro']




def preprocess_image(image: Image.Image) -> np.ndarray:
    """Preprocesses the PIL image for model prediction."""
    image = image.resize((224, 224))
    image_array = tf.keras.preprocessing.image.img_to_array(image)
    image_array = np.expand_dims(image_array, axis=0)
    return image_array / 255.0

def make_gradcam_heatmap(img_array: np.ndarray, last_conv_layer_name="out_relu"):
    """Generates the Grad-CAM heatmap."""
    grad_model = tf.keras.models.Model(
        [model.inputs], [model.get_layer(last_conv_layer_name).output, model.output]
    )
    with tf.GradientTape() as tape:
        last_conv_layer_output, preds = grad_model(img_array)
        pred_index = tf.argmax(preds[0])
        class_channel = preds[:, pred_index]
    grads = tape.gradient(class_channel, last_conv_layer_output)
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    last_conv_layer_output = last_conv_layer_output[0]
    heatmap = last_conv_layer_output @ pooled_grads[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap)
    heatmap = tf.maximum(heatmap, 0) / (tf.math.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy()

def create_gradcam_overlay(image: Image.Image, heatmap: np.ndarray, alpha=0.5):
    """Overlays the heatmap on the original image and returns the result."""
    # Convert PIL image to OpenCV format
    img_cv = np.array(image.resize((224, 224)))
    img_cv = cv2.cvtColor(img_cv, cv2.COLOR_RGB2BGR)

    # Resize heatmap and apply colormap
    heatmap = np.uint8(255 * heatmap)
    heatmap = cv2.resize(heatmap, (img_cv.shape[1], img_cv.shape[0]))
    jet = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)

    # Superimpose the heatmap
    superimposed_img = jet * alpha + img_cv
    superimposed_img = np.clip(superimposed_img, 0, 255).astype(np.uint8)
    return superimposed_img

def generate_ai_explanation(disease_name: str) -> str:
    """Uses Gemini to generate a text explanation for the disease."""
    if os.getenv("GEMINI_API_KEY") is None:
        return "AI Explanation not available. API key is not configured."
    try:
        model_gen = genai.GenerativeModel('gemini-1.5-flash-latest')
        if disease_name.lower() == 'healthy':
            return "The model has determined the leaf is healthy, showing no signs of disease."
        prompt = f"You are a plant pathologist. A deep learning model identified a rice leaf disease as '{disease_name}'. In one simple sentence, describe the key visual symptoms of {disease_name} that the model likely identified."
        response = model_gen.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return f"Error generating AI explanation: {e}"


# --- API ENDPOINT ---

@app.post("/predict/")
async def predict_full(file: UploadFile = File(...)):
    """
    Receives an image, predicts the disease, generates a Grad-CAM heatmap,
    and provides an AI-generated explanation.
    """
    # 1. Read and preprocess the image
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    processed_image = preprocess_image(image)

    # 2. Make a prediction
    predictions = model.predict(processed_image)
    predicted_index = np.argmax(predictions[0])
    predicted_class = CLASS_NAMES[predicted_index]
    confidence = float(np.max(predictions[0]) * 100)

    # 3. Generate AI text explanation
    ai_explanation = generate_ai_explanation(predicted_class)

    # 4. Generate Grad-CAM heatmap and overlay
    heatmap = make_gradcam_heatmap(processed_image)
    overlay_image = create_gradcam_overlay(image, heatmap)

    # 5. Encode the overlay image to Base64
    _, buffer = cv2.imencode('.jpg', overlay_image)
    grad_cam_base64 = base64.b64encode(buffer).decode('utf-8')

    # 6. Encode the original image to Base64
    original_image_base64 = base64.b64encode(contents).decode('utf-8')

   
    return {
        "filename": file.filename,
        "predicted_class": predicted_class,
        "confidence_percent": round(confidence, 2),
        "ai_explanation": ai_explanation,
        "original_image_base64": original_image_base64,
        "grad_cam_image_base64": grad_cam_base64
    }

