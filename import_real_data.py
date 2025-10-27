#!/usr/bin/env python3
"""
강릉고등학교 총동문회 실제 데이터 임포트 스크립트
CSV 파일에서 동문 정보를 읽어 Firestore에 업로드합니다.
"""

import csv
import re
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

def extract_graduation_year(nickname_or_label):
    """닉네임이나 라벨에서 졸업 기수 추출 (예: '21회' -> 2021년으로 추정)"""
    if not nickname_or_label:
        return None
    
    # "21회", "(21회)", "Z-001 ::: 21회" 등에서 숫자 추출
    match = re.search(r'(\d+)회', str(nickname_or_label))
    if match:
        year_suffix = int(match.group(1))
        # 21회 -> 2021년, 46회 -> 2046년은 미래이므로 1946년으로 조정
        if year_suffix <= 50:  # 50회 이하는 최근 졸업생
            base_year = 2000
        else:  # 51회 이상은 1900년대
            base_year = 1900
        return base_year + year_suffix
    
    return None

def clean_phone_number(phone):
    """전화번호 정리 (010-1234-5678 형식으로 통일)"""
    if not phone:
        return ""
    
    # 숫자만 추출
    digits = re.sub(r'\D', '', phone)
    
    # 휴대전화 번호 (010으로 시작)
    if digits.startswith('010') and len(digits) == 11:
        return f"{digits[:3]}-{digits[3:7]}-{digits[7:]}"
    
    # 일반 전화번호 (지역번호 포함)
    if len(digits) >= 9:
        if len(digits) == 9:  # 02-123-4567
            return f"{digits[:2]}-{digits[2:5]}-{digits[5:]}"
        elif len(digits) == 10:  # 031-123-4567
            return f"{digits[:3]}-{digits[3:6]}-{digits[6:]}"
    
    return phone  # 형식이 맞지 않으면 원본 반환

def parse_csv_and_upload():
    """CSV 파일 파싱 및 Firestore 업로드"""
    
    print("=" * 70)
    print("🏫 강릉고등학교 총동문회 실제 데이터 임포트")
    print("=" * 70)
    
    # 기존 샘플 데이터 삭제 확인
    print("\n⚠️  경고: 기존 샘플 데이터를 삭제하고 실제 데이터로 교체합니다.")
    response = input("계속하시겠습니까? (yes/no): ")
    if response.lower() != 'yes':
        print("❌ 작업이 취소되었습니다.")
        return
    
    # 기존 데이터 삭제
    print("\n🗑️  기존 데이터 삭제 중...")
    alumni_ref = db.collection('alumni')
    docs = alumni_ref.stream()
    deleted_count = 0
    for doc in docs:
        doc.reference.delete()
        deleted_count += 1
    print(f"✅ {deleted_count}개의 기존 데이터가 삭제되었습니다.")
    
    # CSV 파일 읽기
    print("\n📂 CSV 파일 읽기 중...")
    csv_file = '/home/user/flutter_app/contacts.csv'
    
    uploaded_count = 0
    skipped_count = 0
    error_count = 0
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            try:
                # 이름 조합
                first_name = row.get('First Name', '').strip()
                last_name = row.get('Last Name', '').strip()
                name = f"{first_name}{last_name}" if last_name else first_name
                
                if not name:
                    skipped_count += 1
                    continue
                
                # 전화번호 (Phone 1 우선)
                phone_raw = row.get('Phone 1 - Value', '').strip()
                phone = clean_phone_number(phone_raw)
                
                if not phone or not phone.startswith('010'):
                    # 휴대전화 번호가 없으면 스킵
                    skipped_count += 1
                    continue
                
                # 졸업년도 추출
                nickname = row.get('Nickname', '').strip()
                labels = row.get('Labels', '').strip()
                graduation_year = extract_graduation_year(nickname) or extract_graduation_year(labels)
                
                if not graduation_year:
                    graduation_year = 2000  # 기본값
                
                # 이메일
                email = row.get('E-mail 1 - Value', '').strip()
                
                # 직장/직책
                company = row.get('Organization Name', '').strip() or '미등록'
                job_title = row.get('Organization Title', '').strip() or '미등록'
                
                # 주소
                address = row.get('Address 1 - Formatted', '').strip()
                if not address:
                    city = row.get('Address 1 - City', '').strip()
                    region = row.get('Address 1 - Region', '').strip()
                    if city or region:
                        address = f"{region} {city}".strip()
                
                # 비고 (한마디)
                notes = row.get('Notes', '').strip()
                bio = notes if notes else f"안녕하세요! {name}입니다."
                
                # Firestore 문서 데이터
                alumni_data = {
                    'name': name,
                    'phone': phone,
                    'graduation_year': graduation_year,
                    'email': email,
                    'company': company,
                    'job_title': job_title,
                    'address': address,
                    'birth_date': '',
                    'school_class': '',
                    'hobbies': '',
                    'bio': bio[:200],  # 최대 200자
                    'profile_photo_url': '',
                    'is_verified': True,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'updated_at': firestore.SERVER_TIMESTAMP,
                }
                
                # 문서 ID는 전화번호 (하이픈 제거)
                doc_id = phone.replace('-', '')
                
                # Firestore에 저장
                alumni_ref.document(doc_id).set(alumni_data)
                uploaded_count += 1
                
                # 진행 상황 출력
                if uploaded_count % 100 == 0:
                    print(f"📝 진행중... {uploaded_count}명 업로드 완료")
                
            except Exception as e:
                error_count += 1
                if error_count <= 5:  # 처음 5개 오류만 출력
                    print(f"⚠️  오류 발생 (행 스킵): {e}")
    
    print(f"\n{'=' * 70}")
    print("✅ 데이터 임포트 완료!")
    print(f"{'=' * 70}")
    print(f"📊 업로드 성공: {uploaded_count}명")
    print(f"⏭️  스킵: {skipped_count}명 (이름 없음 또는 휴대전화 없음)")
    print(f"❌ 오류: {error_count}건")
    print(f"{'=' * 70}")

if __name__ == '__main__':
    try:
        parse_csv_and_upload()
    except Exception as e:
        print(f"\n❌ 치명적 오류 발생: {e}")
        import traceback
        traceback.print_exc()
