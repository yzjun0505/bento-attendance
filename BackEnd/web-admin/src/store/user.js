import { defineStore } from 'pinia'
import { ref } from 'vue'
import { login as loginApi, getProfile } from '@/api/auth'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const refreshToken = ref(localStorage.getItem('refresh_token') || '')
  const userInfo = ref(null)

  async function login(username, password) {
    const res = await loginApi({ username, password })
    token.value = res.data.access_token
    refreshToken.value = res.data.refresh_token || ''
    userInfo.value = res.data.user
    localStorage.setItem('token', res.data.access_token)
    if (res.data.refresh_token) {
      localStorage.setItem('refresh_token', res.data.refresh_token)
    }
    return res
  }

  async function fetchProfile() {
    const res = await getProfile()
    userInfo.value = res.data
    return res
  }

  function logout() {
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('refresh_token')
  }

  return { token, refreshToken, userInfo, login, fetchProfile, logout }
})
