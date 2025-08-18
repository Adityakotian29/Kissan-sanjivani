import tensorflow as tf
from tensorflow.keras import models, layers
import matplotlib.pyplot as plt
import numpy as np
import cv2  
import os

DATASET_PATH = r"/kaggle/input/rice-disease-detection/Rice Leaf Disease Images"

BATCH_SIZE = 32
IMAGE_SIZE = 256
CHANNELS = 3
EPOCHS = 20 

print("Loading dataset from directory...")

dataset = tf.keras.preprocessing.image_dataset_from_directory(
    DATASET_PATH,
    shuffle=True,
    image_size=(IMAGE_SIZE, IMAGE_SIZE),
    batch_size=BATCH_SIZE
)

class_names = dataset.class_names
n_classes = len(class_names)
print(f"Found {n_classes} classes: {class_names}")


def get_dataset_partitions_tf(ds, train_split=0.8, val_split=0.1, test_split=0.1, shuffle=True, shuffle_size=10000):
    assert (train_split + test_split + val_split) == 1
    
    ds_size = len(ds)
    
    if shuffle:
        ds = ds.shuffle(shuffle_size, seed=12)
    
    train_size = int(train_split * ds_size)
    val_size = int(val_split * ds_size)
    
    train_ds = ds.take(train_size)
    val_ds = ds.skip(train_size).take(val_size)
    test_ds = ds.skip(train_size).skip(val_size)
    
    return train_ds, val_ds, test_ds


train_ds, val_ds, test_ds = get_dataset_partitions_tf(dataset)
print(f"Training batches: {len(train_ds)}, Validation batches: {len(val_ds)}, Test batches: {len(test_ds)}")


AUTOTUNE = tf.data.AUTOTUNE
train_ds = train_ds.cache().shuffle(1000).prefetch(buffer_size=AUTOTUNE)
val_ds = val_ds.cache().prefetch(buffer_size=AUTOTUNE)
test_ds = test_ds.cache().prefetch(buffer_size=AUTOTUNE)

data_augmentation = tf.keras.Sequential([
    layers.RandomFlip("horizontal_and_vertical"),
    layers.RandomRotation(0.2),
])

# Apply augmentation only to the training dataset
train_ds = train_ds.map(lambda x, y: (data_augmentation(x, training=True), y)).prefetch(buffer_size=AUTOTUNE)


def create_model(input_shape, num_classes):
    """Creates the CNN model."""
    model = models.Sequential([
        layers.Input(shape=input_shape),
        layers.Rescaling(1./255),
        layers.Conv2D(32, (3,3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3,3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3,3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        layers.Conv2D(64, (3, 3), activation='relu', name="last_conv_layer"),
        layers.MaxPooling2D((2, 2)),
        layers.Flatten(),
        layers.Dense(64, activation='relu'),

        layers.Dense(num_classes, activation='softmax'),
    ])
    
    model.compile(
        optimizer='adam',
        loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=False),
        metrics=['accuracy']
    )
    
    return model

input_shape = (IMAGE_SIZE, IMAGE_SIZE, CHANNELS)
model = create_model(input_shape, n_classes)
model.summary()

print("\nStarting model training...")
history = model.fit(
    train_ds,
    batch_size=BATCH_SIZE,
    validation_data=val_ds,
    verbose=1, 
    epochs=EPOCHS,
)
print("Model training finished.")


print("\nEvaluating model on the test set...")
scores = model.evaluate(test_ds)
print(f"Test Loss: {scores[0]}")
print(f"Test Accuracy: {scores[1]}")

def plot_training_results(history, epochs):
    acc = history.history['accuracy']
    val_acc = history.history['val_accuracy']
    loss = history.history['loss']
    val_loss = history.history['val_loss']
    
    epoch_range = range(epochs)

    plt.figure(figsize=(14, 6))
    plt.subplot(1, 2, 1)
    plt.plot(epoch_range, acc, label='Training Accuracy')
    plt.plot(epoch_range, val_acc, label='Validation Accuracy')
    plt.legend(loc='lower right')
    plt.title('Training and Validation Accuracy')

    plt.subplot(1, 2, 2)
    plt.plot(epoch_range, loss, label='Training Loss')
    plt.plot(epoch_range, val_loss, label='Validation Loss')
    plt.legend(loc='upper right')
    plt.title('Training and Validation Loss')
    plt.show()

plot_training_results(history, EPOCHS)

import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
import textwrap


print("\nSetting up detailed explanations for model predictions...")

def get_eli5_explanation(predicted_class, confidence, actual_class=None):
    """
    Generates detailed, informative explanations for rice disease predictions.
    This version includes 'Blast' and removes 'Leaf Smut'.
    """

    disease_explanations = {
        "Bacterial leaf blight": {
            "what_is_it": "Bacterial leaf blight is caused by the bacterium Xanthomonas oryzae. It's one of the most serious bacterial diseases affecting rice worldwide.",
            "target_areas": "🎯 Target Areas: Leaf edges and tips, leaf sheaths, and sometimes entire leaves. The bacteria enter through water pores and wounds.",
            "visual_symptoms": "👀 What to Look For: Yellow to brown lesions along leaf margins, water-soaked appearance, 'kresek' symptom (wilting of entire tillers), and bacterial ooze in morning dew.",
            "why_detected": "🤖 Why I Think This: I detected characteristic leaf margin yellowing and lesions with a wavy pattern typical of bacterial infection.",
            "severity": "⚠️ Impact: Can cause 20-40% yield loss in severe cases. Most damaging during wet, warm weather conditions.",
            "management": "💡 Management: Use resistant varieties, avoid over-fertilization with nitrogen, ensure proper field drainage, and apply copper-based bactericides if needed."
        },
        "Blast": {
            "what_is_it": "Rice Blast is a destructive fungal disease caused by Magnaporthe oryzae. It can infect all above-ground parts of the rice plant.",
            "target_areas": "🎯 Target Areas: Leaves (Leaf Blast), stem nodes (Node Blast), and the neck of the panicle (Neck Blast), which is the most damaging.",
            "visual_symptoms": "👀 What to Look For: Diamond-shaped or spindle-shaped lesions on leaves with gray or white centers and brown or reddish borders. Infected necks turn brown to black and can break.",
            "why_detected": "🤖 Why I Think This: I identified the distinct diamond-shaped lesions with grayish centers and dark borders, a classic symptom of Rice Blast.",
            "severity": "⚠️ Impact: Extremely high. Neck blast can cause complete crop loss (100% yield loss) by preventing grain formation. It is a major threat to rice production globally.",
            "management": "💡 Management: Use resistant varieties, apply appropriate fungicides preventively, manage water and nitrogen levels carefully, and remove infected crop debris."
        },
        "Brown spot": {
            "what_is_it": "Brown spot is a fungal disease caused by Bipolaris oryzae. It's often an indicator of nutrient-deficient soil.",
            "target_areas": "🎯 Target Areas: Leaves, leaf sheaths, panicles, and grains. Affects plants at all growth stages.",
            "visual_symptoms": "👀 What to Look For: Small, circular to oval brown spots with gray or white centers. Spots may have yellow halos and can merge into large blotches.",
            "why_detected": "🤖 Why I Think This: I identified multiple small, round brown spots with lighter centers, scattered across the leaf surface in a pattern typical of this fungal issue.",
            "severity": "⚠️ Impact: Reduces photosynthesis and grain quality. Can cause significant yield loss (10-45%) if not managed, especially in poor soil conditions.",
            "management": "💡 Management: Improve soil fertility (especially potassium), ensure balanced nutrition, use resistant varieties, and apply fungicides during favorable conditions."
        },
        "Healthy": {
            "what_is_it": "This rice plant shows no signs of disease! Healthy rice has vibrant green leaves, strong stems, and good overall vigor.",
            "target_areas": "🎯 What I See: Uniform green coloration, no lesions or spots, strong upright growth, and healthy leaf structure throughout the plant.",
            "visual_symptoms": "👀 Signs of Health: Bright green leaves without discoloration, clean leaf surfaces, strong stems, and active growth patterns.",
            "why_detected": "🤖 Why I Think This: My analysis shows a uniform green color, the absence of spots or lesions, and a healthy leaf texture, indicating no signs of stress or disease.",
            "importance": "🌟 Why This Matters: Healthy plants achieve maximum yield potential, have better grain quality, and are more resistant to environmental stresses.",
            "maintenance": "💡 Keep It Healthy: Maintain proper nutrition, ensure adequate water management, monitor for early disease signs, and follow integrated pest management practices."
        },
        "Tungro": {
            "what_is_it": "Tungro is a viral disease complex transmitted by green leafhoppers. It involves two different viruses working together.",
            "target_areas": "🎯 Target Areas: Affects the entire plant systemically. The virus spreads through the plant's vascular system, stunting its growth.",
            "visual_symptoms": "👀 What to Look For: Yellow-orange discoloration of leaves (starting from the tip), stunted growth, reduced number of tillers, and empty or partially filled grains.",
            "why_detected": "🤖 Why I Think This: I identified the significant yellow-orange leaf discoloration and stunted plant appearance characteristic of a systemic viral infection like Tungro.",
            "severity": "⚠️ Impact: Can cause 10-100% yield loss depending on how early the infection occurs. Younger plants are much more susceptible to severe damage.",
            "management": "💡 Management: Control the leafhopper vector with insecticides, use resistant varieties, remove and destroy infected plants early, and avoid planting near infected fields."
        }
    }

    class_key = predicted_class

    if "blight" in predicted_class.lower(): class_key = "Bacterial leaf blight"
    elif "blast" in predicted_class.lower(): class_key = "Blast"
    elif "brown" in predicted_class.lower(): class_key = "Brown spot"
    elif "healthy" in predicted_class.lower(): class_key = "Healthy"
    elif "tungro" in predicted_class.lower(): class_key = "Tungro"

    explanation = disease_explanations.get(class_key, {})


    text_parts = [
        f"🌾 DIAGNOSIS: {predicted_class}",
        f"🎯 CONFIDENCE LEVEL: {confidence}% confident",
        f"{'='*50}"
    ]

    if "what_is_it" in explanation: text_parts.append(f"📋 DISEASE OVERVIEW:\n{explanation['what_is_it']}")
    if "target_areas" in explanation: text_parts.append(explanation['target_areas'])
    if "visual_symptoms" in explanation: text_parts.append(explanation['visual_symptoms'])
    if "why_detected" in explanation: text_parts.append(explanation['why_detected'])

    if predicted_class.lower() != "healthy":
        if "severity" in explanation: text_parts.append(explanation['severity'])
        if "management" in explanation: text_parts.append(explanation['management'])
    else:
        if "importance" in explanation: text_parts.append(explanation['importance'])
        if "maintenance" in explanation: text_parts.append(explanation['maintenance'])

    if actual_class:
        if predicted_class == actual_class:
            text_parts.append("✅ VALIDATION: Correct identification! The AI successfully detected this condition.")
        else:
            text_parts.append(f"❌ CORRECTION: AI predicted {predicted_class}, but actual condition is {actual_class}. This helps improve the model's learning.")

    return "\n\n".join(text_parts)

def create_confidence_meter(confidence):
    """Creates a simple visual confidence meter"""
    filled_bars = int(confidence / 10)
    empty_bars = 10 - filled_bars
    meter = "█" * filled_bars + "░" * empty_bars
    return f"Confidence: [{meter}] {confidence}%"


print("Generating a clear, spacious report with embedded explanations...")

fig, axes = plt.subplots(2, 2, figsize=(24, 28))
fig.suptitle("🌾 Rice Disease Detection Report 🌾", fontsize=32, y=0.96)

axes = axes.flatten() 

for images, labels in test_ds.take(1):
  
    for i in range(4):
        if i >= len(images): 
            axes[i].axis('off')
            continue

        ax = axes[i]
        img_tensor = images[i]
        img_array = tf.expand_dims(img_tensor, 0)

        preds = model.predict(img_array, verbose=0)
        predicted_class_index = np.argmax(preds[0])
        confidence = round(100 * np.max(preds[0]), 2)

        actual_class = class_names[labels[i]]
        predicted_class = class_names[predicted_class_index]

      
        ax.imshow(img_tensor.numpy().astype(np.uint8))

        
        confidence_meter = create_confidence_meter(confidence)
        short_title = f"Prediction: {predicted_class}\nActual: {actual_class}"
        title_color = 'darkgreen' if predicted_class == actual_class else 'darkred'
        ax.set_title(short_title, color=title_color, fontsize=18, pad=10)
        ax.axis("off")

        
        eli5_explanation = get_eli5_explanation(predicted_class, confidence, actual_class)

        
        plot_text = "\n".join(eli5_explanation.split('\n\n')[1:])

        ax.text(0.5, -0.15, plot_text,
                transform=ax.transAxes,
                fontsize=14,
                verticalalignment='top',
                horizontalalignment='center',
                wrap=True,
                bbox=dict(boxstyle='round,pad=0.8', fc='ivory', alpha=0.8))

plt.tight_layout(rect=[0, 0, 1, 0.95])
fig.subplots_adjust(hspace=0.6) 
plt.show()



def predict_and_explain_single_image(image_path, model, class_names):
    """
    Loads an image from a file path, gets a prediction and explanation
    from the model, and displays the result in a clear format.
    """
    print(f"\nProcessing image: {image_path}")


    IMG_SIZE = 256

    try:
        
        img = tf.keras.utils.load_img(
            image_path, target_size=(IMG_SIZE, IMG_SIZE)
        )
        img_array = tf.keras.utils.img_to_array(img)
        img_array = tf.expand_dims(img_array, 0) # Create a batch

        
        predictions = model.predict(img_array, verbose=0)
        predicted_index = np.argmax(predictions[0])
        confidence = 100 * np.max(predictions[0])
        predicted_class = class_names[predicted_index]

        
        explanation = get_eli5_explanation(predicted_class, round(confidence, 2))

        
        plt.figure(figsize=(10, 12))
        plt.imshow(img)
        plt.title(f"Diagnosis: {predicted_class}", fontsize=20, pad=20)
        plt.axis("off")

        plot_text = "\n".join(explanation.split('\n\n')[1:])

        plt.figtext(0.5, 0.01, plot_text,
                    ha="center",
                    fontsize=14,
                    wrap=True,
                    bbox=dict(boxstyle='round,pad=0.8', fc='whitesmoke', alpha=0.9))

        plt.show()

    except FileNotFoundError:
        print(f"❌ ERROR: The file was not found at '{image_path}'. Please check the path and try again.")
    except Exception as e:
        print(f"An error occurred: {e}")



print("\n" + "="*80)
print("🔬 PREDICTING ON A SINGLE IMAGE")
print("="*80)


my_image_path = '/kaggle/input/rice-disease-detection/Rice Leaf Disease Images/Healthy/HEALTHY_IMAGE1.jpg'



if 'path/to/your/image.jpg' in my_image_path:
    print("❗ Please update the 'my_image_path' variable with the actual path to your image.")
else:
   
    predict_and_explain_single_image(my_image_path, model, class_names)
