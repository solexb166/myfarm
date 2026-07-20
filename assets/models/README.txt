Place the trained model files here:

  cassava.tflite          (from the Colab notebook in ../ml/)
  cassava_labels.txt       (from the same notebook)

The app loads them as:  assets/models/<crop>.tflite + <crop>_labels.txt
Crops without a model file show "Soon" in the picker and are disabled.
