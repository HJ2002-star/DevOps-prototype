@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo Finesse 원본 문서 삭제 스크립트
echo 총 72개 파일을 삭제합니다. (이미 문서정리 폴더에 복사된 파일이어야 합니다)
pause

if exist "C:\Users\park2\Downloads\Finesse — TETR.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse — TETR.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse — TETR.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse — TETR.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\2. Finesse-프로젝트제안서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\2. Finesse-프로젝트제안서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\2. Finesse-프로젝트제안서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\2. Finesse-프로젝트제안서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\3. Finesse-프로젝트기획서-v1_0.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\3. Finesse-프로젝트기획서-v1_0.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\3. Finesse-프로젝트기획서-v1_0.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\3. Finesse-프로젝트기획서-v1_0.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\5. Finesse-요구사항정의서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\5. Finesse-요구사항정의서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\5. Finesse-요구사항정의서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\5. Finesse-요구사항정의서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\4. Finesse-기술스택문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\4. Finesse-기술스택문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\4. Finesse-기술스택문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\4. Finesse-기술스택문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\8. Finesse-규칙관련문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\8. Finesse-규칙관련문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\8. Finesse-규칙관련문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\8. Finesse-규칙관련문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\7. Finesse-데이터명세서-v4.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\7. Finesse-데이터명세서-v4.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\7. Finesse-데이터명세서-v4.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\7. Finesse-데이터명세서-v4.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\0. Finesse-handoff-summary.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\0. Finesse-handoff-summary.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\0. Finesse-handoff-summary.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\0. Finesse-handoff-summary.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\6. Finesse-기능명세서-v1_0.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\6. Finesse-기능명세서-v1_0.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\6. Finesse-기능명세서-v1_0.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\구 버전\6. Finesse-기능명세서-v1_0.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기술스택문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기술스택문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기술스택문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기술스택문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트제안서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트제안서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트제안서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트제안서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-규칙관련문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-규칙관련문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-규칙관련문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-규칙관련문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-팀구성및역할분담.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-팀구성및역할분담.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-팀구성및역할분담.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-팀구성및역할분담.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기능명세서-v1_0.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기능명세서-v1_0.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기능명세서-v1_0.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-기능명세서-v1_0.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-요구사항정의서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-요구사항정의서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-요구사항정의서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-요구사항정의서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트기획서-v1_0.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트기획서-v1_0.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트기획서-v1_0.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-프로젝트기획서-v1_0.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-데이터명세서-v5.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-데이터명세서-v5.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-데이터명세서-v5.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-데이터명세서-v5.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-handoff-summary.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-handoff-summary.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-handoff-summary.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-handoff-summary.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트제안서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트제안서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트제안서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트제안서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-팀구성및역할분담.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-팀구성및역할분담.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-팀구성및역할분담.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-팀구성및역할분담.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-규칙관련문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-규칙관련문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-규칙관련문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-규칙관련문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-요구사항정의서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-요구사항정의서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-요구사항정의서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-요구사항정의서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기술스택문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기술스택문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기술스택문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기술스택문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기능명세서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기능명세서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기능명세서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-기능명세서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트기획서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트기획서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트기획서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-프로젝트기획서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-데이터명세서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-데이터명세서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-데이터명세서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-데이터명세서.docx
)
if exist "C:\Users\park2\Downloads\Finesse-Mock서버도입제안.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-Mock서버도입제안.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-Mock서버도입제안.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-Mock서버도입제안.docx
)
if exist "C:\Users\park2\Downloads\Finesse-MockLLM-설명서(비전공자용).docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-MockLLM-설명서(비전공자용).docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-MockLLM-설명서(비전공자용).docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-MockLLM-설명서(비전공자용).docx
)
if exist "C:\Users\park2\Downloads\finesse-mock-llm-prototype.zip" (
    del /f /q "C:\Users\park2\Downloads\finesse-mock-llm-prototype.zip"
    echo [삭제됨] C:\Users\park2\Downloads\finesse-mock-llm-prototype.zip
) else (
    echo [없음] C:\Users\park2\Downloads\finesse-mock-llm-prototype.zip
)
if exist "C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드.docx
)
if exist "C:\Users\park2\Downloads\FinesseMock개발환경세션요약20260903.docx" (
    del /f /q "C:\Users\park2\Downloads\FinesseMock개발환경세션요약20260903.docx"
    echo [삭제됨] C:\Users\park2\Downloads\FinesseMock개발환경세션요약20260903.docx
) else (
    echo [없음] C:\Users\park2\Downloads\FinesseMock개발환경세션요약20260903.docx
)
if exist "C:\Users\park2\Downloads\Finesse-MockLLM-검토정리.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse-MockLLM-검토정리.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-MockLLM-검토정리.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-MockLLM-검토정리.pdf
)
if exist "C:\Users\park2\Downloads\finessedevenv.zip" (
    del /f /q "C:\Users\park2\Downloads\finessedevenv.zip"
    echo [삭제됨] C:\Users\park2\Downloads\finessedevenv.zip
) else (
    echo [없음] C:\Users\park2\Downloads\finessedevenv.zip
)
if exist "C:\Users\park2\Downloads\FinesseMock개발환경세션요약.docx" (
    del /f /q "C:\Users\park2\Downloads\FinesseMock개발환경세션요약.docx"
    echo [삭제됨] C:\Users\park2\Downloads\FinesseMock개발환경세션요약.docx
) else (
    echo [없음] C:\Users\park2\Downloads\FinesseMock개발환경세션요약.docx
)
if exist "C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드-v2.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드-v2.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드-v2.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-Mock개발환경-구축가이드-v2.docx
)
if exist "C:\Users\park2\Downloads\Finesse-Mock환경-담당자별-안내.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-Mock환경-담당자별-안내.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-Mock환경-담당자별-안내.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-Mock환경-담당자별-안내.docx
)
if exist "C:\Users\park2\Downloads\DevOps-prototype-main.zip" (
    del /f /q "C:\Users\park2\Downloads\DevOps-prototype-main.zip"
    echo [삭제됨] C:\Users\park2\Downloads\DevOps-prototype-main.zip
) else (
    echo [없음] C:\Users\park2\Downloads\DevOps-prototype-main.zip
)
if exist "C:\Users\park2\Downloads\FinesseMock개발환경세션요약2.docx" (
    del /f /q "C:\Users\park2\Downloads\FinesseMock개발환경세션요약2.docx"
    echo [삭제됨] C:\Users\park2\Downloads\FinesseMock개발환경세션요약2.docx
) else (
    echo [없음] C:\Users\park2\Downloads\FinesseMock개발환경세션요약2.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\Finesse-MockLLM-이채팅세션요약.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\Finesse-MockLLM-이채팅세션요약.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\Finesse-MockLLM-이채팅세션요약.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\Finesse-MockLLM-이채팅세션요약.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\Finesse-1부-MockLLM_PC현황보고.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\Finesse-1부-MockLLM_PC현황보고.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\Finesse-1부-MockLLM_PC현황보고.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\Finesse-1부-MockLLM_PC현황보고.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-MockLLM문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-MockLLM문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-MockLLM문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-MockLLM문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-Mock개발환경-세션요약.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-Mock개발환경-세션요약.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-Mock개발환경-세션요약.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\Finesse-Mock개발환경-세션요약.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-Mock개발환경-세션요약-2026-09-03.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-Mock개발환경-세션요약-2026-09-03.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-Mock개발환경-세션요약-2026-09-03.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\몰입형 본과정\기본 문서\구 버전\Finesse-Mock개발환경-세션요약-2026-09-03.md
)
if exist "C:\Users\park2\Downloads\Finesse-CICD구축문서.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-CICD구축문서.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-CICD구축문서.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-CICD구축문서.docx
)
if exist "C:\Users\park2\Downloads\cicd_docker_k8s_relationship.png" (
    del /f /q "C:\Users\park2\Downloads\cicd_docker_k8s_relationship.png"
    echo [삭제됨] C:\Users\park2\Downloads\cicd_docker_k8s_relationship.png
) else (
    echo [없음] C:\Users\park2\Downloads\cicd_docker_k8s_relationship.png
)
if exist "C:\Users\park2\Downloads\Finesse-DevOps-CICD-세션요약.md" (
    del /f /q "C:\Users\park2\Downloads\Finesse-DevOps-CICD-세션요약.md"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-DevOps-CICD-세션요약.md
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-DevOps-CICD-세션요약.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\Finesse-CICD구축-세션요약.md" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\Finesse-CICD구축-세션요약.md"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\Finesse-CICD구축-세션요약.md
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\Finesse-CICD구축-세션요약.md
)
if exist "C:\Users\park2\Downloads\finesse-monorepo\README.md" (
    del /f /q "C:\Users\park2\Downloads\finesse-monorepo\README.md"
    echo [삭제됨] C:\Users\park2\Downloads\finesse-monorepo\README.md
) else (
    echo [없음] C:\Users\park2\Downloads\finesse-monorepo\README.md
)
if exist "C:\Users\park2\Downloads\finesse-monorepo-skeleton.zip" (
    del /f /q "C:\Users\park2\Downloads\finesse-monorepo-skeleton.zip"
    echo [삭제됨] C:\Users\park2\Downloads\finesse-monorepo-skeleton.zip
) else (
    echo [없음] C:\Users\park2\Downloads\finesse-monorepo-skeleton.zip
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-GitHub관련문서.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-GitHub관련문서.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-GitHub관련문서.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-GitHub관련문서.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-레포구조비교.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-레포구조비교.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-레포구조비교.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-레포구조비교.docx
)
if exist "C:\Users\park2\Downloads\finesse_runtime_architecture.png" (
    del /f /q "C:\Users\park2\Downloads\finesse_runtime_architecture.png"
    echo [삭제됨] C:\Users\park2\Downloads\finesse_runtime_architecture.png
) else (
    echo [없음] C:\Users\park2\Downloads\finesse_runtime_architecture.png
)
if exist "C:\Users\park2\Downloads\03_확정미확정_분류.md" (
    del /f /q "C:\Users\park2\Downloads\03_확정미확정_분류.md"
    echo [삭제됨] C:\Users\park2\Downloads\03_확정미확정_분류.md
) else (
    echo [없음] C:\Users\park2\Downloads\03_확정미확정_분류.md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-2부-피드백수렴양식.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-2부-피드백수렴양식.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-2부-피드백수렴양식.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-2부-피드백수렴양식.docx
)
if exist "C:\Users\park2\Downloads\nickname_masking_spec.md" (
    del /f /q "C:\Users\park2\Downloads\nickname_masking_spec.md"
    echo [삭제됨] C:\Users\park2\Downloads\nickname_masking_spec.md
) else (
    echo [없음] C:\Users\park2\Downloads\nickname_masking_spec.md
)
if exist "C:\Users\park2\Downloads\nickname_masking_spec (1).md" (
    del /f /q "C:\Users\park2\Downloads\nickname_masking_spec (1).md"
    echo [삭제됨] C:\Users\park2\Downloads\nickname_masking_spec (1).md
) else (
    echo [없음] C:\Users\park2\Downloads\nickname_masking_spec (1).md
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문A_APORIA.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문A_APORIA.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문A_APORIA.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문A_APORIA.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문B_김가현.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문B_김가현.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문B_김가현.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-참고문헌-논문B_김가현.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-닉네임마스킹검증.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-닉네임마스킹검증.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-닉네임마스킹검증.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-닉네임마스킹검증.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-학교PC배정현황.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-학교PC배정현황.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-학교PC배정현황.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-학교PC배정현황.docx
)
if exist "C:\Users\park2\Downloads\Finesse-회의요약-1page.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse-회의요약-1page.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-회의요약-1page.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-회의요약-1page.pdf
)
if exist "C:\Users\park2\Downloads\Finesse-회의요약.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse-회의요약.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse-회의요약.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse-회의요약.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-회의요약.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-회의요약.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-회의요약.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse-회의요약.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse 회의 1페이지 요약.pdf" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse 회의 1페이지 요약.pdf"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse 회의 1페이지 요약.pdf
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse 회의 1페이지 요약.pdf
)
if exist "C:\Users\park2\Downloads\기업연계_프로젝트_요약서_검토의견_조성빈.docx" (
    del /f /q "C:\Users\park2\Downloads\기업연계_프로젝트_요약서_검토의견_조성빈.docx"
    echo [삭제됨] C:\Users\park2\Downloads\기업연계_프로젝트_요약서_검토의견_조성빈.docx
) else (
    echo [없음] C:\Users\park2\Downloads\기업연계_프로젝트_요약서_검토의견_조성빈.docx
)
if exist "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse.docx" (
    del /f /q "C:\Users\park2\OneDrive\바탕 화면\회의\Finesse.docx"
    echo [삭제됨] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse.docx
) else (
    echo [없음] C:\Users\park2\OneDrive\바탕 화면\회의\Finesse.docx
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.pdf
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_2.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_2.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_2.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_2.pdf
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_3.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_3.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_3.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_3.pdf
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_4.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_4.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_4.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_4.pdf
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_5.pdf" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_5.pdf"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_5.pdf
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본_5.pdf
)
if exist "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.docx" (
    del /f /q "C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.docx"
    echo [삭제됨] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.docx
) else (
    echo [없음] C:\Users\park2\Downloads\Finesse_9월10일_회의정리본.docx
)

echo.
echo 완료되었습니다.
pause