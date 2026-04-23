#!/bin/sh
# ============================================================================
# TEST SCRIPT: cek_rootfs_sebelum_install.sh
# 
# Fungsi: Menguji apakah rootfs siap untuk menjalankan RMxxx_rgmii_toolkit.sh
# Output: Status LULUS (bisa jalan) atau GAGAL (tidak bisa jalan)
# ============================================================================

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variabel untuk tracking status
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
CANNOT_WRITE_ROOTFS=0
CANNOT_SYMLINK=0

# Direktori pengujian
USRDATA_DIR="/usrdata"
TEST_DIR="$USRDATA_DIR/test_$$"
ROOTFS_WRITE_TEST="/.rootfs_write_test_$$"

# Fungsi untuk log hasil
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Bersihkan test files
cleanup() {
    rm -f "$ROOTFS_WRITE_TEST" 2>/dev/null
    rm -rf "$TEST_DIR" 2>/dev/null
    rm -f /usrdata/test_symlink 2>/dev/null
    rm -f /data/testfile 2>/dev/null
}

# Trap exit untuk cleanup
trap cleanup EXIT

# ============================================================================
# MULAI PENGUJIAN
# ============================================================================
clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     ROOTFS READINESS TEST FOR RMxxx_rgmii_toolkit.sh              ║"
echo "║     =============================================                 ║"
echo "║  Menguji apakah rootfs siap menjalankan toolkit                   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ----------------------------------------------------------------------------
# TEST 1: Cek space dan inode rootfs
# ----------------------------------------------------------------------------
log_section "TEST 1: Cek Kapasitas Rootfs"

# Get rootfs info
ROOTFS_AVAIL=$(df / | awk 'NR==2 {print $4}')
ROOTFS_AVAIL_MB=$((ROOTFS_AVAIL / 1024))
ROOTFS_USE_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
ROOTFS_TOTAL_MB=$(df / | awk 'NR==2 {print $2}' | awk '{print $1/1024}')

INODE_AVAIL=$(df -i / | awk 'NR==2 {print $4}')
INODE_USE_PERCENT=$(df -i / | awk 'NR==2 {print $5}' | sed 's/%//')

echo "  Total rootfs: ${ROOTFS_TOTAL_MB} MB"
echo "  Available space: ${ROOTFS_AVAIL_MB} MB (${ROOTFS_USE_PERCENT}% used)"
echo "  Available inodes: $INODE_AVAIL (${INODE_USE_PERCENT}% used)"

# Evaluasi space
if [ "$ROOTFS_AVAIL_MB" -lt 5 ]; then
    log_fail "Rootfs hanya memiliki ${ROOTFS_AVAIL_MB} MB (< 5 MB) - KRITIS"
elif [ "$ROOTFS_AVAIL_MB" -lt 20 ]; then
    log_warn "Rootfs hanya memiliki ${ROOTFS_AVAIL_MB} MB (< 20 MB) - HATI-HATI"
else
    log_pass "Rootfs memiliki ${ROOTFS_AVAIL_MB} MB space (>= 20 MB)"
fi

# Evaluasi inode
if [ "$INODE_AVAIL" -lt 100 ]; then
    log_fail "Inode tersisa hanya $INODE_AVAIL (< 100) - TIDAK BISA BUAT FILE"
elif [ "$INODE_AVAIL" -lt 500 ]; then
    log_warn "Inode tersisa $INODE_AVAIL (< 500) - HATI-HATI"
else
    log_pass "Inode tersisa $INODE_AVAIL (>= 500)"
fi

# ----------------------------------------------------------------------------
# TEST 2: Cek apakah bisa write ke rootfs (required untuk symlink)
# ----------------------------------------------------------------------------
log_section "TEST 2: Uji Write Access ke Rootfs"

# Test write ke rootfs
echo "test" > "$ROOTFS_WRITE_TEST" 2>/dev/null
if [ -f "$ROOTFS_WRITE_TEST" ]; then
    WRITE_OK=1
    rm -f "$ROOTFS_WRITE_TEST"
    log_pass "Rootfs bisa di-write (write test berhasil)"
else
    WRITE_OK=0
    CANNOT_WRITE_ROOTFS=1
    log_fail "Rootfs TIDAK bisa di-write (read-only atau full)"
    
    # Coba remount RW
    log_info "Mencoba remount rootfs sebagai read-write..."
    mount -o remount,rw / 2>/dev/null
    
    # Test ulang
    echo "test" > "$ROOTFS_WRITE_TEST" 2>/dev/null
    if [ -f "$ROOTFS_WRITE_TEST" ]; then
        rm -f "$ROOTFS_WRITE_TEST"
        log_pass "Remount RW berhasil! Sekarang rootfs bisa di-write"
        WRITE_OK=1
    else
        log_fail "Remount RW GAGAL - rootfs masih read-only"
    fi
fi

# ----------------------------------------------------------------------------
# TEST 3: Uji kemampuan membuat symlink ke /usr/bin
# ----------------------------------------------------------------------------
log_section "TEST 3: Uji Kemampuan Symlink ke /usr/bin"

if [ "$WRITE_OK" -eq 1 ]; then
    # Buat test file dummy di /data
    mkdir -p /data 2>/dev/null
    echo "#!/bin/sh" > /data/test_binary
    echo "echo 'test binary works'" >> /data/test_binary
    chmod +x /data/test_binary
    
    # Coba buat symlink ke /usr/bin
    SYMLINK_PATH="/usr/bin/test_binary_$$"
    ln -sf /data/test_binary "$SYMLINK_PATH" 2>/dev/null
    
    if [ -L "$SYMLINK_PATH" ]; then
        log_pass "Symlink ke /usr/bin BERHASIL dibuat"
        # Cleanup
        rm -f "$SYMLINK_PATH"
    else
        CANNOT_SYMLINK=1
        log_fail "Symlink ke /usr/bin GAGAL (rootfs mungkin penuh inode)"
        
        # Cek error spesifik
        ln -sf /data/test_binary "$SYMLINK_PATH" 2>&1 | head -1
    fi
    
    # Cleanup test binary
    rm -f /data/test_binary
else
    log_fail "Skip symlink test karena rootfs tidak bisa write"
    CANNOT_SYMLINK=1
fi

# ----------------------------------------------------------------------------
# TEST 4: Cek apakah /usrdata bisa write (harusnya bisa)
# ----------------------------------------------------------------------------
log_section "TEST 4: Uji Write Access ke /usrdata"

mkdir -p "$TEST_DIR" 2>/dev/null
if [ -d "$TEST_DIR" ]; then
    echo "test" > "$TEST_DIR/test.txt"
    if [ -f "$TEST_DIR/test.txt" ]; then
        log_pass "/usrdata bisa di-write (normal)"
        rm -rf "$TEST_DIR"
        USRDATA_OK=1
    else
        log_fail "/usrdata GAGAL write - masalah serius"
        USRDATA_OK=0
    fi
else
    log_fail "Tidak bisa membuat direktori di /usrdata"
    USRDATA_OK=0
fi

# ----------------------------------------------------------------------------
# TEST 5: Cek apakah /data ada dan bisa dibaca
# ----------------------------------------------------------------------------
log_section "TEST 5: Cek Direktori /data"

if [ -d "/data" ]; then
    log_pass "Direktori /data exists"
    
    # Cek isi /data
    DATA_FILES=$(ls -la /data/ 2>/dev/null | wc -l)
    if [ "$DATA_FILES" -gt 3 ]; then
        log_pass "Direktori /data berisi $((DATA_FILES - 3)) file/dir"
    else
        log_warn "Direktori /data kosong"
    fi
else
    log_warn "Direktori /data tidak ditemukan"
    # Coba cari alternatif
    if [ -d "/usrdata" ]; then
        log_info "Menggunakan /usrdata sebagai alternatif /data"
    fi
fi

# ----------------------------------------------------------------------------
# TEST 6: Cek kemampuan membuat file di /tmp
# ----------------------------------------------------------------------------
log_section "TEST 6: Uji /tmp (temporary directory)"

# /tmp biasanya tmpfs, tidak masalah walau rootfs penuh
TMP_TEST="/tmp/test_$$.tmp"
echo "test" > "$TMP_TEST" 2>/dev/null
if [ -f "$TMP_TEST" ]; then
    log_pass "/tmp bisa di-write (normal)"
    rm -f "$TMP_TEST"
else
    log_fail "/tmp GAGAL write - masalah serius"
fi

# ----------------------------------------------------------------------------
# TEST 7: Simulasi PATH modification (tanpa symlink)
# ----------------------------------------------------------------------------
log_section "TEST 7: Uji PATH Modification (Alternatif Tanpa Symlink)"

# Test apakah bisa menambah PATH ke /data
if [ -d "/data" ]; then
    OLD_PATH="$PATH"
    export PATH=/data:$PATH
    log_pass "PATH berhasil ditambah dengan /data"
    log_info "  PATH baru: $PATH"
    export PATH="$OLD_PATH"
else
    log_warn "Tidak bisa test PATH karena /data tidak ada"
fi

# ----------------------------------------------------------------------------
# KESIMPULAN
# ----------------------------------------------------------------------------
log_section "KESIMPULAN DAN REKOMENDASI"

echo ""
echo "Ringkasan hasil pengujian:"
echo "  ✅ Pass: $PASS_COUNT"
echo "  ⚠️  Warn: $WARN_COUNT"
echo "  ❌ Fail: $FAIL_COUNT"
echo ""

# Tentukan apakah toolkit bisa dijalankan
CAN_RUN=0
REASON=""

if [ "$USRDATA_OK" -eq 0 ]; then
    CAN_RUN=0
    REASON="/usrdata tidak bisa write - kegagalan sistem"
elif [ "$WRITE_OK" -eq 1 ] && [ "$CANNOT_SYMLINK" -eq 0 ]; then
    CAN_RUN=1
    REASON="Rootfs normal, symlink bisa dibuat - Toolkit bisa dijalankan NORMAL"
elif [ "$WRITE_OK" -eq 0 ] && [ "$USRDATA_OK" -eq 1 ]; then
    CAN_RUN=2
    REASON="Rootfs read-only, tapi /usrdata writeable - Toolkit bisa dijalankan dengan MODIFIKASI PATH"
else
    CAN_RUN=0
    REASON="Kondisi kritis - rootfs tidak bisa write dan/atau /usrdata bermasalah"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HASIL AKHIR:${NC}"
echo ""

case $CAN_RUN in
    1)
        echo -e "${GREEN}✓ LULUS${NC} - $REASON"
        echo ""
        echo -e "${GREEN}Rekomendasi:${NC}"
        echo "  Script RMxxx_rgmii_toolkit.sh BISA dijalankan langsung"
        echo "  Tidak perlu modifikasi"
        ;;
    2)
        echo -e "${YELLOW}⚠️  LULUS DENGAN MODIFIKASI${NC} - $REASON"
        echo ""
        echo -e "${YELLOW}Rekomendasi:${NC}"
        echo "  Script RMxxx_rgmii_toolkit.sh BISA dijalankan dengan modifikasi:"
        echo ""
        echo "  --- Tambahkan di BARIS PERTAMA script ---"
        echo "  # MODIFICATION FOR READ-ONLY ROOTFS"
        echo "  export PATH=/data:/bin:/sbin:/usr/bin:/usr/sbin:\$PATH"
        echo "  mount() { return 0; }  # Skip remount attempts"
        echo "  ln() { return 0; }     # Skip symlink attempts"
        echo "  -----------------------------------------"
        ;;
    0)
        echo -e "${RED}✗ GAGAL${NC} - $REASON"
        echo ""
        echo -e "${RED}Rekomendasi:${NC}"
        echo "  Script RMxxx_rgmii_toolkit.sh TIDAK BISA dijalankan"
        echo ""
        echo "  Langkah perbaikan:"
        echo "  1. Bersihkan rootfs terlebih dahulu"
        echo "  2. Atau gunakan bind mount sebagai alternatif"
        echo "  3. Atau extract manual file-file ke /usrdata"
        ;;
esac

echo ""
echo -e "${BLUE}========================================${NC}"
echo ""

# ----------------------------------------------------------------------------
# OPSIONAL: Tampilkan command untuk fix jika gagal
# ----------------------------------------------------------------------------
if [ $CAN_RUN -eq 0 ] && [ "$WRITE_OK" -eq 0 ]; then
    echo -e "${YELLOW}Command untuk mencoba fix rootfs read-only:${NC}"
    echo ""
    echo "  # Remount sebagai read-write"
    echo "  mount -o remount,rw /"
    echo ""
    echo "  # Jika gagal, cek filesystem"
    echo "  dmesg | grep -i error | tail -10"
    echo "  mount | grep ' / '"
    echo ""
fi

if [ "$ROOTFS_AVAIL_MB" -lt 10 ] && [ "$WRITE_OK" -eq 0 ]; then
    echo -e "${YELLOW}Command untuk membersihkan rootfs:${NC}"
    echo ""
    echo "  # Hapus file temporary"
    echo "  rm -rf /tmp/* 2>/dev/null"
    echo "  rm -rf /var/log/*.gz 2>/dev/null"
    echo "  rm -rf /var/cache/opkg/* 2>/dev/null"
    echo ""
    echo "  # Cari file besar"
    echo "  du -sh /* 2>/dev/null | sort -rh | head -10"
    echo ""
fi

echo ""
echo -e "${CYAN}Pengujian selesai.${NC}"
echo ""

exit $CAN_RUN
