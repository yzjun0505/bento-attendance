import { defineStore } from 'pinia'
import { ref } from 'vue'
import { login as loginApi, getProfile } from '@/api/auth'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const userInfo = ref(null)

  async function login(username, password) {
    const res = await loginApi({ username, password })
    token.value = res.data.access_token
    userInfo.value = res.data.user
    localStorage.setItem('token', res.data.access_token)
    return res
  }

  async function fetchProfile() {
    const res = await getProfile()
    userInfo.value = res.data
    return res
  }

  function logout() {
    token.value = ''
    userInfo.value = null
    localStorage.removeItem('token')
  }

  return { token, userInfo, login, fetchProfile, logout }
})
