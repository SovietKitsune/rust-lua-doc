let root

function changeTheme(theme) {
    localStorage.setItem('theme', theme)

    root.className = 'h-full'

    root.classList.add(theme)
}

window.addEventListener('load', () => {
    root = document.getElementsByTagName('html')[0]

    if (localStorage.getItem('theme')) {
        changeTheme(localStorage.getItem('theme'))
    }
})
