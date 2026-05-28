<template>
  <div class="login-page">
    <!-- 动态背景 -->
    <div class="login-bg">
      <div class="bg-circle c1"></div>
      <div class="bg-circle c2"></div>
      <div class="bg-circle c3"></div>
    </div>

    <div class="login-card fade-in-up">
      <div class="login-header">
        <div class="login-logo">
          <img :src="logoUrl" alt="境图项目协同管理平台" />
        </div>
        <h1 class="login-title">境图项目协同管理平台</h1>
        <p class="login-subtitle">项目进度 · 现场协同 · 智能管理</p>
      </div>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        class="login-form"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="username">
          <el-input
            v-model="form.username"
            placeholder="请输入用户名"
            :prefix-icon="User"
            size="large"
            class="login-input"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            :prefix-icon="Lock"
            size="large"
            show-password
            class="login-input"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-button
          type="primary"
          size="large"
          class="login-btn"
          :loading="loading"
          @click="handleLogin"
        >
          {{ loading ? '登录中...' : '登 录' }}
        </el-button>
      </el-form>

    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/store/user'
import { User, Lock } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import logoUrl from '@/assets/jingmap-logo.png'

const router = useRouter()
const userStore = useUserStore()
const formRef = ref(null)
const loading = ref(false)

const form = reactive({
  username: '',
  password: ''
})

const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

async function handleLogin() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    const res = await userStore.login(form.username, form.password)
    if (res.data?.user?.role === 'client') {
      userStore.logout()
      ElMessage.warning('甲方用户请使用手机端查看项目进度')
      return
    }
    ElMessage.success('登录成功')
    router.push('/dashboard')
  } catch (e) {
    // 错误已在拦截器中处理
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f0f4f8;
  position: relative;
  overflow: hidden;
}

.login-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.bg-circle {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.2;
}

.bg-circle.c1 {
  width: 400px;
  height: 400px;
  background: #4f8cff;
  top: -100px;
  right: -50px;
  animation: float 8s ease-in-out infinite;
}

.bg-circle.c2 {
  width: 300px;
  height: 300px;
  background: #a78bfa;
  bottom: -80px;
  left: -50px;
  animation: float 10s ease-in-out infinite reverse;
}

.bg-circle.c3 {
  width: 200px;
  height: 200px;
  background: #34d399;
  top: 50%;
  left: 50%;
  animation: float 12s ease-in-out infinite;
}

@keyframes float {
  0%, 100% { transform: translate(0, 0); }
  33% { transform: translate(30px, -20px); }
  66% { transform: translate(-20px, 30px); }
}

.login-card {
  width: 420px;
  padding: 48px 40px;
  border-radius: var(--radius-lg);
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(24px);
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  z-index: 1;
}

.login-header {
  text-align: center;
  margin-bottom: 36px;
}

.login-logo {
  width: 64px;
  height: 64px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  overflow: hidden;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.12);
}

.login-logo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.login-title {
  font-size: 24px;
  font-weight: 700;
  color: #1a202c;
  margin-bottom: 8px;
}

.login-subtitle {
  font-size: 13px;
  color: #718096;
  letter-spacing: 2px;
}

.login-form {
  margin-top: 8px;
}

.login-form :deep(.el-input__wrapper) {
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  box-shadow: none !important;
  height: 48px;
}

.login-form :deep(.el-input__wrapper:hover) {
  border-color: rgba(79, 140, 255, 0.4);
}

.login-form :deep(.el-input__wrapper.is-focus) {
  border-color: #4f8cff;
  background: #fff;
}

.login-form :deep(.el-input__inner) {
  color: #1a202c;
  font-size: 14px;
}

.login-form :deep(.el-input__inner::placeholder) {
  color: #a0aec0;
}

.login-form :deep(.el-input__prefix .el-icon) {
  color: #a0aec0;
}

.login-btn {
  width: 100%;
  height: 48px;
  border-radius: 10px;
  font-size: 16px;
  font-weight: 600;
  background: var(--gradient-blue);
  border: none;
  margin-top: 8px;
  letter-spacing: 4px;
  transition: var(--transition);
}

.login-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 24px rgba(79, 140, 255, 0.35);
}

</style>
