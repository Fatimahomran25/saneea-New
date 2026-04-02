print("FILE STARTED")

import os

os.environ["HF_HOME"] = "D:/huggingface"
os.environ["TRANSFORMERS_CACHE"] = "D:/huggingface"

from flask import Flask, request, jsonify
import torch
torch.set_num_threads(1)

import open_clip
from PIL import Image
import requests
from io import BytesIO

app = Flask(__name__)

print("BEFORE MODEL")

model, _, preprocess = open_clip.create_model_and_transforms(
    "RN50",
    pretrained="openai"
)

print("AFTER MODEL")

tokenizer = open_clip.get_tokenizer("RN50")

device = "cpu"
model = model.to(device)
model.eval()


# تعديل فاطمه
# تم حذف منطق matched_count القديم
# تم حذف منطق threshold القديم الذي كان يعتمد على عد الصور المطابقة
# وتم الإبقاء على اسم الدالة analyze_match حتى لا يتأثر الاستدعاء الحالي
# وتم تغيير داخلها لتصبح تعتمد على:
# 1) الطلب العام = 100%
# 2) الطلب التفصيلي = الأساسي 90% والصفة 10%
# نهاية تعديلات فاطمه
def analyze_match(description, image_urls):
    if not image_urls:
        return 0, 0

    # تعديل فاطمه
    # تنظيف وصف المستخدم من الكلمات غير المهمة
    stop_words = {
        "i", "want", "need", "a", "an", "the",
        "please", "to", "for", "looking", "look",
        "my", "me", "and"
    }

    words = [
        w.strip(".,!?").lower()
        for w in description.split()
        if w.strip(".,!?").lower() not in stop_words
    ]
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # في حال كان الوصف فارغ بعد التنظيف
    if not words:
        return 0, 0
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # آخر كلمة تعتبر الأساس
    # وما قبلها صفات
    main_word = words[-1]
    attribute_words = words[:-1]

    # إذا الوصف كلمة واحدة فقط فهو طلب عام
    single_word_mode = len(words) == 1
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # تم فصل الكلمة الأساسية عن الصفات في المقارنة
    text_list = [main_word] + attribute_words
    text_tokens = tokenizer(text_list).to(device)
    # نهاية تعديلات فاطمه

    with torch.no_grad():
        text_features = model.encode_text(text_tokens)
        text_features /= text_features.norm(dim=-1, keepdim=True)

    # تعديل فاطمه
    # حفظ أفضل نسبة تم الوصول لها بين جميع الصور
    best_percentage = 0
    # نهاية تعديلات فاطمه

    for url in image_urls:
        try:
            response = requests.get(url, timeout=15)
            response.raise_for_status()

            image = Image.open(BytesIO(response.content)).convert("RGB")
            image_tensor = preprocess(image).unsqueeze(0).to(device)

            with torch.no_grad():
                image_features = model.encode_image(image_tensor)
                image_features /= image_features.norm(dim=-1, keepdim=True)

            similarities = (image_features @ text_features.T).squeeze().tolist()

            # تعديل فاطمه
            # إذا كانت النتيجة رقم واحد فقط نحولها إلى list
            if isinstance(similarities, (int, float)):
                similarities = [similarities]
            # نهاية تعديلات فاطمه

            # تعديل فاطمه
            # منطق النسبة الجديد
            main_score = similarities[0] if len(similarities) > 0 else 0
            percentage = 0

            # الحالة 1:
            # الطلب العام مثل logo
            # إذا تحقق الأساسي فوق 0.20 = 100%
            if single_word_mode:
                if main_score > 0.20:
                    percentage = 100
                else:
                    percentage = 0

            # الحالة 2:
            # الطلب التفصيلي مثل black logo
            else:
                # إذا الأساسي لم يتحقق فلا نكمل
                if main_score <= 0.20:
                    percentage = 0
                else:
                    # الأساسي = 90%
                    percentage = 90

                    # الصفة أو الصفات = 10%
                    if len(attribute_words) > 0:
                        attribute_weight = 10 / len(attribute_words)

                        for i in range(1, len(text_list)):
                            if i >= len(similarities):
                                continue

                            score = similarities[i]

                            # الصفة متحققة بالكامل
                            if score > 0.30:
                                percentage += attribute_weight

                            # الصفة متحققة جزئيًا
                            elif score > 0.20:
                                percentage += attribute_weight * 0.5

            if percentage > best_percentage:
                best_percentage = percentage
            # نهاية تعديلات فاطمه

        except Exception as e:
            print(f"Failed image: {url} | {e}")

    # تعديل فاطمه
    # لم نعد نستخدم matchedWorks كعدد فعلي
    # ونرجع 0 فقط حتى لا ينكسر الكود الحالي في Flutter
    return 0, round(best_percentage)
    # نهاية تعديلات فاطمه


@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.get_json(force=True)

    description = data.get("description", "")
    images = data.get("images", [])

    matched, percentage = analyze_match(description, images)

    return jsonify({
        "matchedWorks": matched,
        "matchPercentage": percentage
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
print("FILE STARTED")

import os

os.environ["HF_HOME"] = "D:/huggingface"
os.environ["TRANSFORMERS_CACHE"] = "D:/huggingface"

from flask import Flask, request, jsonify
import torch
torch.set_num_threads(1)

import open_clip
from PIL import Image
import requests
from io import BytesIO

app = Flask(__name__)

print("BEFORE MODEL")

model, _, preprocess = open_clip.create_model_and_transforms(
    "RN50",
    pretrained="openai"
)

print("AFTER MODEL")

tokenizer = open_clip.get_tokenizer("RN50")

device = "cpu"
model = model.to(device)
model.eval()


# تعديل فاطمه
# تم حذف منطق matched_count القديم
# تم حذف منطق threshold القديم الذي كان يعتمد على عد الصور المطابقة
# وتم الإبقاء على اسم الدالة analyze_match حتى لا يتأثر الاستدعاء الحالي
# وتم تغيير داخلها لتصبح تعتمد على:
# 1) الطلب العام = 100%
# 2) الطلب التفصيلي = الأساسي 90% والصفة 10%
# نهاية تعديلات فاطمه
def analyze_match(description, image_urls):
    if not image_urls:
        return 0, 0

    # تعديل فاطمه
    # تنظيف وصف المستخدم من الكلمات غير المهمة
    stop_words = {
        "i", "want", "need", "a", "an", "the",
        "please", "to", "for", "looking", "look",
        "my", "me", "and"
    }

    words = [
        w.strip(".,!?").lower()
        for w in description.split()
        if w.strip(".,!?").lower() not in stop_words
    ]
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # في حال كان الوصف فارغ بعد التنظيف
    if not words:
        return 0, 0
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # آخر كلمة تعتبر الأساس
    # وما قبلها صفات
    main_word = words[-1]
    attribute_words = words[:-1]

    # إذا الوصف كلمة واحدة فقط فهو طلب عام
    single_word_mode = len(words) == 1
    # نهاية تعديلات فاطمه

    # تعديل فاطمه
    # تم فصل الكلمة الأساسية عن الصفات في المقارنة
    text_list = [main_word] + attribute_words
    text_tokens = tokenizer(text_list).to(device)
    # نهاية تعديلات فاطمه

    with torch.no_grad():
        text_features = model.encode_text(text_tokens)
        text_features /= text_features.norm(dim=-1, keepdim=True)

    # تعديل فاطمه
    # حفظ أفضل نسبة تم الوصول لها بين جميع الصور
    best_percentage = 0
    # نهاية تعديلات فاطمه

    for url in image_urls:
        try:
            response = requests.get(url, timeout=15)
            response.raise_for_status()

            image = Image.open(BytesIO(response.content)).convert("RGB")
            image_tensor = preprocess(image).unsqueeze(0).to(device)

            with torch.no_grad():
                image_features = model.encode_image(image_tensor)
                image_features /= image_features.norm(dim=-1, keepdim=True)

            similarities = (image_features @ text_features.T).squeeze().tolist()

            # تعديل فاطمه
            # إذا كانت النتيجة رقم واحد فقط نحولها إلى list
            if isinstance(similarities, (int, float)):
                similarities = [similarities]
            # نهاية تعديلات فاطمه

            # تعديل فاطمه
            # منطق النسبة الجديد
            main_score = similarities[0] if len(similarities) > 0 else 0
            percentage = 0

            # الحالة 1:
            # الطلب العام مثل logo
            # إذا تحقق الأساسي فوق 0.20 = 100%
            if single_word_mode:
                if main_score > 0.20:
                    percentage = 100
                else:
                    percentage = 0

            # الحالة 2:
            # الطلب التفصيلي مثل black logo
            else:
                # إذا الأساسي لم يتحقق فلا نكمل
                if main_score <= 0.20:
                    percentage = 0
                else:
                    # الأساسي = 90%
                    percentage = 90

                    # الصفة أو الصفات = 10%
                    if len(attribute_words) > 0:
                        attribute_weight = 10 / len(attribute_words)

                        for i in range(1, len(text_list)):
                            if i >= len(similarities):
                                continue

                            score = similarities[i]

                            # الصفة متحققة بالكامل
                            if score > 0.30:
                                percentage += attribute_weight

                            # الصفة متحققة جزئيًا
                            elif score > 0.20:
                                percentage += attribute_weight * 0.5

            if percentage > best_percentage:
                best_percentage = percentage
            # نهاية تعديلات فاطمه

        except Exception as e:
            print(f"Failed image: {url} | {e}")

    # تعديل فاطمه
    # لم نعد نستخدم matchedWorks كعدد فعلي
    # ونرجع 0 فقط حتى لا ينكسر الكود الحالي في Flutter
    return 0, round(best_percentage)
    # نهاية تعديلات فاطمه


@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.get_json(force=True)

    description = data.get("description", "")
    images = data.get("images", [])

    matched, percentage = analyze_match(description, images)

    return jsonify({
        "matchedWorks": matched,
        "matchPercentage": percentage
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)