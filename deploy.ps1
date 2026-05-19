# 🎯 파워쉘 자체 인코딩을 UTF-8로 완전 고정
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "     JEJUAC INTEGRATED MANAGEMENT SCRIPT (PowerShell v3)" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   1) Flutter Web Build & Zip (Build and compress)"
    Write-Host "   2) Git One-Shot Commit & Push (All changes)"
    Write-Host "   3) [ALL] Flutter Build + Zip + Git Push Continuous"
    Write-Host "   4) Exit"
    Write-Host "================================================================" -ForegroundColor Cyan
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Select task number (1~4)"

    switch ($choice) {
        "1" {
            Write-Host "`n[INFO] Moving to 'frontend' folder and starting Flutter Web Build..." -ForegroundColor Yellow
            if (Test-Path "frontend") {
                Set-Location frontend
                flutter clean; flutter pub get; flutter build web --release
                
                # 🎯 [압축 기능 추가] 기존 web.zip이 있다면 지우고 새로 압축합니다.
                Write-Host "`nCompiling completed. Zipping 'build/web' folder..." -ForegroundColor Blue
                if (Test-Path "build\web.zip") { Remove-Item "build\web.zip" -Force }
                Compress-Archive -Path "build\web\*" -DestinationPath "build\web.zip" -Force
                
                Set-Location ..
                Write-Host "`n============================================================" -ForegroundColor Green
                Write-Host "Flutter Web Build & Compression Complete!" -ForegroundColor Green
                Write-Host "Upload 'frontend/build/web.zip' to your FTP server."
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
                flutter clean; flutter pub get; flutter build web --release
                
                # 🎯 [압축 기능 추가] 종합 모드에서도 동일하게 압축 진행
                Write-Host "`nZipping 'build/web' folder..." -ForegroundColor Blue
                if (Test-Path "build\web.zip") { Remove-Item "build\web.zip" -Force }
                Compress-Archive -Path "build\web\*" -DestinationPath "build\web.zip" -Force
                
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
            Write-Host "`nAll Processes Complete! (Build + Zip + Git Push)" -ForegroundColor Green
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