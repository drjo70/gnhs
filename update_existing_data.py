#!/usr/bin/env python3
"""
기존 Firestore 데이터를 CSV에서 추가 필드로 업데이트
"""
import firebase_admin
from firebase_admin import credentials, firestore
import csv

# Firebase Admin SDK 초기화
try:
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass  # Already initialized

db = firestore.client()

def clean_phone(phone):
    """전화번호에서 하이픈 제거"""
    return phone.replace('-', '').replace(' ', '').strip()

def update_alumni_data():
    """CSV 데이터로 기존 Firestore 문서 업데이트"""
    
    print("=" * 80)
    print("📊 Firestore 데이터 업데이트 시작 (추가 필드 반영)")
    print("=" * 80)
    
    # CSV 데이터를 딕셔너리로 로드
    phone_to_data = {}
    
    with open('contacts.csv', 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            phone = clean_phone(row.get('Phone 1 - Value', ''))
            if phone.startswith('010'):
                phone_to_data[phone] = {
                    'email2': row.get('E-mail 2 - Value', '').strip(),
                    'department': row.get('Organization Department', '').strip(),
                    'address2': row.get('Address 2 - Formatted', '').strip(),
                    'notes': row.get('Notes', '').strip(),
                    'phone2': clean_phone(row.get('Phone 2 - Value', '')),
                }
    
    print(f"📋 CSV에서 {len(phone_to_data)}개 레코드 로드 완료")
    
    # Firestore에서 기존 문서 가져오기
    alumni_ref = db.collection('alumni')
    docs = alumni_ref.stream()
    
    updated_count = 0
    batch = db.batch()
    batch_count = 0
    
    for doc in docs:
        doc_id = doc.id  # phone number
        
        if doc_id in phone_to_data:
            extra_data = phone_to_data[doc_id]
            
            # 추가 필드 업데이트
            batch.update(doc.reference, extra_data)
            batch_count += 1
            updated_count += 1
            
            # 배치 커밋 (500개마다)
            if batch_count >= 500:
                batch.commit()
                print(f"✅ 배치 커밋: {updated_count}개 업데이트 완료")
                batch = db.batch()
                batch_count = 0
    
    # 마지막 배치 커밋
    if batch_count > 0:
        batch.commit()
    
    print("\n" + "=" * 80)
    print(f"✅ 업데이트 완료: {updated_count}개 문서")
    print("추가된 필드: email2, department, address2, notes, phone2")
    print("=" * 80)

if __name__ == '__main__':
    update_alumni_data()
