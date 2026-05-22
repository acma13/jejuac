# 🎯 파워쉘 자체 인코딩을 UTF-8로 완전 고정
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ==========================================
# 🔐 [오라클 클라우드 SFTP 설정 정보]
# ==========================================
$SFTP_HOST = "158.180.89.23"
$SFTP_USER = "ubuntu"
$KEY_PATH  = "C:\YoungK\OracleKeys\ssh-key-2026-04-09.key"
# ==========================================

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "     JEJUAC INTEGRATED MANAGEMENT SCRIPT (PowerShell v3)" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   1) Flutter Web Build, Zip & Auto SFTP Send"
    Write-Host "   2) Git One-Shot Commit & Push (All changes)"
    Write-Host "   3) [ALL-IN-ONE] Build + Zip + SFTP Send + Git Push"
    Write-Host "   4) Exit"
    Write-Host "================================================================" -ForegroundColor Cyan
}

# 🚀 파워쉘 공식 승인 동사(Send)를 사용한 SFTP 업로드 함수
function Send-To-SFTP {
    Write-Host "`n[SFTP] Starting secure web.zip upload using SSH Key..." -ForegroundColor Yellow
    $localFile = "build\web\web.zip"
    
    if (-not (Test-Path $localFile)) {
        Write-Host "Error: Local web.zip not found at $localFile" -ForegroundColor Red
        return
    }

    if (-not (Test-Path $KEY_PATH)) {
        Write-Host "Error: SSH Key file not found at $KEY_PATH" -ForegroundColor Red
        return
    }

    try {
        $batchFile = "sftp_batch.txt"
        $remotePath = "/home/ubuntu/jejuac/frontend/build/web/web.zip"
        
        "put `"$localFile`" `"$remotePath`"" | Out-File -FilePath $batchFile -Encoding ascii -Force

        Write-Host "Connecting securely to $SFTP_HOST via SFTP..." -ForegroundColor Gray
        sftp -i "$KEY_PATH" -b $batchFile -o StrictHostKeyChecking=no "$SFTP_USER`@$SFTP_HOST"

        if (Test-Path $batchFile) { Remove-Item $batchFile -Force }
        Write-Host "`n[SUCCESS] web.zip has been successfully uploaded via SFTP!" -ForegroundColor Green
    } catch {
        Write-Host "`n❌ SFTP Upload Failed!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Select task number (1~4)"

    switch ($choice) {
        "1" {
            Write-Host "`n[INFO] Moving to 'frontend' folder and starting Flutter Web Build..." -ForegroundColor Yellow
            if (Test-Path "frontend") {
                Set-Location frontend
                
                # 🎯 [팀장님 기존 방식으로 원상복구] --web-renderer 옵션을 완전히 제거했습니다.
                flutter clean; flutter pub get; flutter build web --release
                
                Write-Host "`nCompiling completed. Zipping 'build/web' folder..." -ForegroundColor Blue
                if (Test-Path "build\web.zip") { Remove-Item "build\web.zip" -Force }
                Compress-Archive -Path "build\web\*" -DestinationPath "build\web\web.zip" -Force
                
                # 자동으로 SFTP 전송 실행
                Send-To-SFTP
                
                Set-Location ..
                Write-Host "`n============================================================" -ForegroundColor Green
                Write-Host "Frontend Build, Zip, and SFTP Upload Complete!" -ForegroundColor Green
                Write-Host "============================================================" -ForegroundColor Green
            } else {
                Write-Host "Error: 'frontend' folder not found." -ForegroundColor Red
            }
            Read-Host "`nPress Enter to continue..."
        }
        "2" {
            Write-Host "`n[INFO] Checking Git status and adding all files..." -ForegroundColor Yellow
            git add .
            git status
            
            $commit_message = Read-Host "`nEnter Commit Message"
            if ([string]::IsNullOrEmpty($commit_message)) {
                Write-Host "Error: Commit message cannot be empty." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            git commit -m "$commit_message"
            Write-Host "`nPushing to GitHub (origin main)..." -ForegroundColor Yellow
            git push origin main
            Write-Host "`nGit Push Success!" -ForegroundColor Green
            Read-Host "`nPress Enter to continue..."
        }
        "3" {
            Write-Host "`n[STEP 1] Starting Flutter Web Build & Zip..." -ForegroundColor Yellow
            if (Test-Path "frontend") {
                Set-Location frontend
                
                # 🎯 [팀장님 기존 방식으로 원상복구] 종합 모드에서도 옵션을 제거했습니다.
                flutter clean; flutter pub get; flutter build web --release
                
                Write-Host "`nZipping 'build/web' folder..." -ForegroundColor Blue
                if (Test-Path "build\web.zip") { Remove-Item "build\web.zip" -Force }
                Compress-Archive -Path "build\web\*" -DestinationPath "build\web\web.zip" -Force
                
                # SFTP 전송 실행
                Send-To-SFTP
                
                Set-Location ..
            } else {
                Write-Host "Error: 'frontend' folder not found. Action aborted." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            Write-Host "`n[STEP 2] Git staging and status check..." -ForegroundColor Yellow
            git add .
            git status

            $commit_message = Read-Host "`n Enter Commit Message"
            if ([string]::IsNullOrEmpty($commit_message)) {
                Write-Host "Error: Commit message cannot be empty. Push aborted." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            git commit -m "$commit_message"
            Write-Host "`nPushing to GitHub (origin main)..." -ForegroundColor Yellow
            git push origin main
            Write-Host "`nAll Processes Complete! (Build + Zip + SFTP + Git Push)" -ForegroundColor Green
            Read-Host "`nPress Enter to continue..."
        }
        "4" {
            Write-Host "Goodbye!" -ForegroundColor Yellow
            exit
        }
        Default {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}