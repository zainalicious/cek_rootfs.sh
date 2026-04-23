# cek_rootfs.sh

Script untuk mengecek kesiapan root filesystem (rootfs) sebelum menjalankan `RMxxx_rgmii_toolkit.sh`.

---

## 🚀 Cara Pakai (via /tmp)

### 🔽 wget
```sh
cd /tmp
wget https://raw.githubusercontent.com/zainalicious/cek_rootfs.sh/main/cek_rootfs.sh
chmod +x cek_rootfs.sh
./cek_rootfs.sh
```

### 🔽 curl
```sh
cd /tmp
curl -O https://raw.githubusercontent.com/zainalicious/cek_rootfs.sh/main/cek_rootfs.sh
chmod +x cek_rootfs.sh
./cek_rootfs.sh
```

---

## ⚡ One-liner
```sh
cd /tmp && wget -qO- https://raw.githubusercontent.com/zainalicious/cek_rootfs.sh/main/cek_rootfs.sh | sh
```

atau

```sh
cd /tmp && curl -s https://raw.githubusercontent.com/zainalicious/cek_rootfs.sh/main/cek_rootfs.sh | sh
```

---

## 📊 Hasil

- ✅ **LULUS** → bisa langsung jalankan toolkit
- ⚠️ **LULUS DENGAN MODIFIKASI** → perlu penyesuaian
- ❌ **GAGAL** → rootfs belum siap

---

## ⚠️ Jika LULUS DENGAN MODIFIKASI

Tambahkan di awal script toolkit:
```sh
export PATH=/data:/bin:/sbin:/usr/bin:/usr/sbin:$PATH
mount() { return 0; }
ln() { return 0; }
```

---

## 📜 Catatan

- Jalankan sebagai root
- Tidak mengubah sistem (hanya testing)
