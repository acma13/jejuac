# 🎯 파워쉘 자체 인코딩을 UTF-8로 완전 고정
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   🚀 JEJUAC INTEGRATED MANAGEMENT SCRIPT (PowerShell v2)" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   1) Flutter Web Build (Go to frontend and build)"
    Write-Host "   2) Git One-Shot Commit & Push (All changes)"
    Write-Host "   3) [ALL] Flutter Build + Git Push Continuous"
    Write-Host "   4) Exit"
    Write-Host "================================================================" -ForegroundColor Cyan
}

while ($true) {
    Show-Menu
    $choice = Read-Host "👉 Select task number (1~4)"

    switch ($choice) {
        "1" {
            Write-Host "`n[INFO] Moving to 'frontend' folder and starting Flutter Web Build..." -ForegroundColor Yellow
            if (Test-Path "frontend") {
                # 🎯 cd 대신 정식 명령어 Set-Location 사용
                Set-Location frontend
                flutter clean; flutter pub get; flutter build web --release
                Set-Location ..
                Write-Host "`n============================================================" -ForegroundColor Green
                Write-Host "🎉 Flutter Web Build Complete!" -ForegroundColor Green
                Write-Host "Upload files in 'build/web' to your FTP server."
                Write-Host "============================================================" -ForegroundColor Green
            } else {
                Write-Host "❌ Error: 'frontend' folder not found." -ForegroundColor Red
            }
            Read-Host "`nPress Enter to continue..."
        }
        "2" {
            Write-Host "`n[INFO] Checking Git status and adding all files..." -ForegroundColor Yellow
            git add .
            git status
            
            $commit_message = Read-Host "`n💬 Enter Commit Message"
            if ([string]::IsNullOrEmpty($commit_message)) {
                Write-Host "❌ Error: Commit message cannot be empty." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            git commit -m "$commit_message"
            Write-Host "`n🚀 Pushing to GitHub (origin main)..." -ForegroundColor Yellow
            git push origin main
            Write-Host "`n🎉 Git Push Success!" -ForegroundColor Green
            Read-Host "`nPress Enter to continue..."
        }
        "3" {
            Write-Host "`n📂 [STEP 1] Starting Flutter Web Build..." -ForegroundColor Yellow
            if (Test-Path "frontend") {
                # 🎯 cd 대신 정식 명령어 Set-Location 사용
                Set-Location frontend
                flutter clean; flutter pub get; flutter build web --release
                Set-Location ..
            } else {
                Write-Host "❌ Error: 'frontend' folder not found. Action aborted." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            Write-Host "`n📦 [STEP 2] Git staging and status check..." -ForegroundColor Yellow
            git add .
            git status

            $commit_message = Read-Host "`n💬 Enter Commit Message"
            if ([string]::IsNullOrEmpty($commit_message)) {
                Write-Host "❌ Error: Commit message cannot be empty. Push aborted." -ForegroundColor Red
                Read-Host "`nPress Enter to continue..."
                continue
            }

            git commit -m "$commit_message"
            Write-Host "`n🚀 Pushing to GitHub (origin main)..." -ForegroundColor Yellow
            git push origin main
            Write-Host "`n🎉 All Processes Complete! (Build + Git Push)" -ForegroundColor Green
            Read-Host "`nPress Enter to continue..."
        }
        "4" {
            Write-Host "Goodbye!" -ForegroundColor Yellow
            break
        }
        Default {
            Write-Host "❌ Invalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}