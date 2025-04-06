<?php
// 開始會話
session_start();

// 包含資料庫配置
require_once 'db-config.php';

// 處理登出
if (isset($_GET['logout'])) {
    // 清除所有會話變量
    $_SESSION = array();
    
    // 如果要徹底銷毀會話，還要刪除會話 cookie
    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $params["path"], $params["domain"],
            $params["secure"], $params["httponly"]
        );
    }
    
    // 最後銷毀會話
    session_destroy();
    
    // 重定向到登入頁面
    header("Location: admin.php");
    exit;
}

// 處理登入表單提交
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['login'])) {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    // 查詢資料庫中的用戶
    $sql = "SELECT id, username, password FROM users WHERE username = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows == 1) {
        $user = $result->fetch_assoc();
        // 這裡使用簡單驗證，實際應用中應使用 password_verify
        if ($password == "demo") { // 簡化的密碼檢查，實際應使用哈希
            $_SESSION['loggedin'] = true;
            $_SESSION['id'] = $user['id'];
            $_SESSION['username'] = $user['username'];
            // 重定向到管理頁面
            header("Location: admin.php");
            exit;
        } else {
            $login_err = "密碼不正確";
        }
    } else {
        $login_err = "用戶名不存在";
    }
    
    $stmt->close();
}

// 處理新增文章
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['add_post']) && isset($_SESSION['loggedin'])) {
    $title = $_POST['title'];
    $content = $_POST['content'];
    $user_id = $_SESSION['id'];
    
    $sql = "INSERT INTO posts (user_id, title, content) VALUES (?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iss", $user_id, $title, $content);
    
    if ($stmt->execute()) {
        $post_success = "文章新增成功！";
    } else {
        $post_err = "錯誤: " . $stmt->error;
    }
    
    $stmt->close();
}

// 處理刪除文章
if (isset($_GET['delete_post']) && isset($_SESSION['loggedin'])) {
    $post_id = $_GET['delete_post'];
    $user_id = $_SESSION['id'];
    
    // 先檢查是否是用戶自己的文章
    $check_sql = "SELECT id FROM posts WHERE id = ? AND user_id = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("ii", $post_id, $user_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows == 1) {
        // 是自己的文章，可以刪除
        $delete_sql = "DELETE FROM posts WHERE id = ?";
        $delete_stmt = $conn->prepare($delete_sql);
        $delete_stmt->bind_param("i", $post_id);
        
        if ($delete_stmt->execute()) {
            $delete_success = "文章已成功刪除！";
        } else {
            $delete_err = "刪除失敗: " . $delete_stmt->error;
        }
        
        $delete_stmt->close();
    } else {
        $delete_err = "您沒有權限刪除此文章";
    }
    
    $check_stmt->close();
}

// 獲取所有文章
$posts = [];
$sql = "SELECT p.id, p.title, p.content, p.created_at, u.username 
        FROM posts p 
        JOIN users u ON p.user_id = u.id 
        ORDER BY p.created_at DESC";
$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $posts[] = $row;
    }
}
?>

<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>網站管理系統</title>
    <style>
        body {
            font-family: 'Microsoft JhengHei', Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background: #f4f4f4;
            color: #333;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            background: #fff;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .btn {
            display: inline-block;
            padding: 8px 15px;
            background: #3498db;
            color: #fff;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            text-decoration: none;
        }
        .btn:hover {
            background: #2980b9;
            text-decoration: none;
        }
        .btn-danger {
            background: #e74c3c;
        }
        .btn-danger:hover {
            background: #c0392b;
        }
        .form-group {
            margin-bottom: 15px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        .form-control {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        textarea.form-control {
            height: 150px;
        }
        .alert {
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .alert-success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .alert-danger {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .post {
            border-bottom: 1px solid #eee;
            padding-bottom: 20px;
            margin-bottom: 20px;
        }
        .post-title {
            margin-bottom: 5px;
        }
        .post-meta {
            color: #777;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        .login-container {
            max-width: 400px;
            margin: 50px auto;
            padding: 20px;
            background: #fff;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #777;
        }
        .links {
            margin-top: 20px;
        }
        .links a {
            margin: 0 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <?php if (isset($_SESSION['loggedin']) && $_SESSION['loggedin'] === true): ?>
            <div class="header">
                <h1>網站管理系統</h1>
                <div>
                    歡迎, <?php echo htmlspecialchars($_SESSION['username']); ?>! 
                    <a href="admin.php?logout=1" class="btn btn-danger">登出</a>
                </div>
            </div>
            
            <h2>新增文章</h2>
            <?php if (isset($post_success)): ?>
                <div class="alert alert-success"><?php echo $post_success; ?></div>
            <?php endif; ?>
            <?php if (isset($post_err)): ?>
                <div class="alert alert-danger"><?php echo $post_err; ?></div>
            <?php endif; ?>
            
            <form method="post" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]); ?>">
                <div class="form-group">
                    <label for="title">標題</label>
                    <input type="text" name="title" id="title" class="form-control" required>
                </div>
                <div class="form-group">
                    <label for="content">內容</label>
                    <textarea name="content" id="content" class="form-control" required></textarea>
                </div>
                <button type="submit" name="add_post" class="btn">發布文章</button>
            </form>
            
            <h2>文章列表</h2>
            <?php if (isset($delete_success)): ?>
                <div class="alert alert-success"><?php echo $delete_success; ?></div>
            <?php endif; ?>
            <?php if (isset($delete_err)): ?>
                <div class="alert alert-danger"><?php echo $delete_err; ?></div>
            <?php endif; ?>
            
            <?php if (empty($posts)): ?>
                <p>目前沒有文章</p>
            <?php else: ?>
                <?php foreach ($posts as $post): ?>
                    <div class="post">
                        <h3 class="post-title"><?php echo htmlspecialchars($post['title']); ?></h3>
                        <div class="post-meta">
                            作者: <?php echo htmlspecialchars($post['username']); ?> | 
                            發布時間: <?php echo htmlspecialchars($post['created_at']); ?>
                            <?php if ($_SESSION['username'] == $post['username']): ?>
                                | <a href="admin.php?delete_post=<?php echo $post['id']; ?>" 
                                     onclick="return confirm('確定要刪除這篇文章嗎？');">刪除</a>
                            <?php endif; ?>
                        </div>
                        <div class="post-content">
                            <?php echo nl2br(htmlspecialchars($post['content'])); ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
            
            <div class="links">
                <a href="index.html">返回首頁</a> | 
                <a href="phpinfo.php">PHP 資訊</a> | 
                <a href="db-test.php">資料庫測試</a> | 
                <a href="/phpmyadmin/" target="_blank">phpMyAdmin</a>
            </div>
            
        <?php else: ?>
            <div class="login-container">
                <h2>管理員登入</h2>
                <?php if (isset($login_err)): ?>
                    <div class="alert alert-danger"><?php echo $login_err; ?></div>
                <?php endif; ?>
                
                <form method="post" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]); ?>">
                    <div class="form-group">
                        <label for="username">用戶名</label>
                        <input type="text" name="username" id="username" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label for="password">密碼</label>
                        <input type="password" name="password" id="password" class="form-control" required>
                    </div>
                    <button type="submit" name="login" class="btn">登入</button>
                </form>
                
                <p style="margin-top: 20px;">
                    <strong>測試帳號：</strong><br>
                    用戶名: admin 或 user1<br>
                    密碼: demo<br>
                </p>
                
                <div class="links">
                    <a href="index.html">返回首頁</a> | 
                    <a href="db-test.php">資料庫測試頁面</a>
                </div>
            </div>
        <?php endif; ?>
        
        <div class="footer">
            &copy; <?php echo date("Y"); ?> LAMP 自動化部署示範 | 
            伺服器 IP: <?php echo $_SERVER['SERVER_ADDR']; ?>
        </div>
    </div>
</body>
</html> 