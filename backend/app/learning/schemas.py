from typing import Literal

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# نماذج استجابة قسم Learn (للقراءة فقط).
#
# ملاحظات مخطط مهمّة (الحقول الفعلية في قاعدة البيانات):
#   - العناوين تُعاد بالإنجليزية دائمًا (name_en / title_en) بغضّ النظر عن
#     preferred_language؛ تبديل لغة الواجهة مسؤولية الفرونت. الأعمدة العربية
#     (name_ar / title_ar) تبقى في القاعدة دون أن تُستخدم هنا.
#   - subjects/topics ليس لهما عمود status؛ النشر مُمثَّل على مستوى الدرس فقط
#     (lessons.status). نعتبر المادة/الموضوع "منشورًا" إذا احتوى درسًا منشورًا.
#   - subjects ليس لها display_order؛ لذلك ترتيب المواد بالـid فقط.
#   - subjects/topics لهما description (نص واحد)، أمّا الدرس فليس له description
#     بل summary، ونعرضه في حقل description.
#   - لا يوجد thumbnail_url في أي من الجداول ⇒ null دائمًا حاليًا.
#
# إتاحة المحتوى منفصلة عن تقدّم الطالب:
#   - is_available (للدرس): هل محتوى الدرس جاهز للدراسة؟ = الدرس منشور وله
#     بلوك محتوى واحد على الأقل (lesson_blocks). الدرس المنشور بلا محتوى
#     يُعرَض عنوانًا فقط ("Coming soon") ويُعطَّل الدخول إليه.
#   - status (للدرس): تقدّم الطالب فقط (not_started / in_progress / completed)،
#     مستقلّ تمامًا عن is_available.
# ---------------------------------------------------------------------------


class SubjectListItem(BaseModel):
    id: int
    title: str
    description: str | None
    thumbnail_url: str | None  # غير مخزَّن ⇒ null حاليًا.
    # عدد المواضيع المنشورة (التي تحوي درسًا منشورًا) داخل المادة.
    topics_count: int
    # عدد الدروس المنشورة المعروضة داخل تلك المواضيع (شامل "Coming soon").
    lessons_count: int
    # عدد الدروس الجاهزة للدراسة فعلًا (منشورة ولها محتوى).
    available_lessons_count: int


class SubjectListResponse(BaseModel):
    subjects: list[SubjectListItem]


class OutlineLesson(BaseModel):
    id: int
    title: str
    description: str | None  # مصدره lessons.summary.
    display_order: int
    # حالة الدرس لهذا الطالب فقط، من lesson_progress:
    #   not_started (لا صف) / in_progress / completed.
    status: Literal["not_started", "in_progress", "completed"]
    # هل الدرس جاهز للدراسة؟ false ⇒ "Coming soon" + عطّل زر الدخول.
    is_available: bool
    thumbnail_url: str | None  # غير مخزَّن ⇒ null حاليًا.


class OutlineTopic(BaseModel):
    id: int
    title: str
    description: str | None
    display_order: int
    # إجمالي الدروس المنشورة المعروضة داخل الموضوع (= طول lessons، شامل
    # "Coming soon").
    lessons_count: int
    # الدروس الجاهزة للدراسة فعلًا (مقام نسبة التقدّم).
    available_lessons_count: int
    # دروس جاهزة أكملها الطالب داخل الموضوع.
    completed_lessons: int
    # completed_lessons / available_lessons_count × 100
    # (0 إذا لا دروس متاحة، لا يتجاوز 100).
    progress_percentage: float
    lessons: list[OutlineLesson]


class SubjectOutlineResponse(BaseModel):
    id: int
    title: str
    description: str | None
    topics: list[OutlineTopic]
