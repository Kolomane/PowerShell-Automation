let x = 3;
let y = 2;
function update(arg) {
    return Math.random() + y * arg;
}
const result = update(x);
console.log(`result = ${result}`)