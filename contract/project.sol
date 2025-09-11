// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title People's Blogs - Decentralized Blogging Platform
 * @dev A smart contract for creating, managing, and interacting with blog posts on blockchain
 * @author People's Blogs Team
 */
contract Project {
    
    // Struct to represent a blog post
    struct BlogPost {
        uint256 id;
        address author;
        string title;
        string content;
        string[] tags;
        uint256 timestamp;
        uint256 likes;
        uint256 views;
        bool isPublished;
        bool isPremium;
        uint256 tipAmount;
    }
    
    // Struct to represent a blog author
    struct Author {
        address authorAddress;
        string username;
        string bio;
        uint256 totalPosts;
        uint256 totalLikes;
        uint256 totalTips;
        bool isVerified;
        uint256 joinDate;
    }
    
    // Struct for comments
    struct Comment {
        uint256 id;
        uint256 postId;
        address commenter;
        string content;
        uint256 timestamp;
        uint256 likes;
    }
    
    // State variables
    mapping(uint256 => BlogPost) public blogPosts;
    mapping(address => Author) public authors;
    mapping(uint256 => Comment[]) public postComments;
    mapping(address => uint256[]) public authorPosts;
    mapping(uint256 => mapping(address => bool)) public postLikes;
    mapping(uint256 => mapping(address => bool)) public commentLikes;
    mapping(address => mapping(address => bool)) public following;
    
    uint256 public totalPosts;
    uint256 public totalComments;
    uint256 public platformFee = 10; // 1% platform fee on tips
    address public owner;
    
    // Events
    event PostCreated(uint256 indexed postId, address indexed author, string title);
    event PostPublished(uint256 indexed postId, address indexed author);
    event PostLiked(uint256 indexed postId, address indexed liker);
    event PostViewed(uint256 indexed postId, address indexed viewer);
    event CommentAdded(uint256 indexed postId, uint256 indexed commentId, address indexed commenter);
    event TipSent(uint256 indexed postId, address indexed tipper, address indexed author, uint256 amount);
    event AuthorRegistered(address indexed author, string username);
    event AuthorFollowed(address indexed follower, address indexed following);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthor(uint256 _postId) {
        require(msg.sender == blogPosts[_postId].author, "Only post author can call this function");
        _;
    }
    
    modifier postExists(uint256 _postId) {
        require(_postId < totalPosts, "Post does not exist");
        _;
    }
    
    modifier isRegisteredAuthor() {
        require(bytes(authors[msg.sender].username).length > 0, "Author must be registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalPosts = 0;
        totalComments = 0;
    }
    
    /**
     * @dev Core Function 1: Create and publish blog posts
     * @param _title Title of the blog post
     * @param _content Content of the blog post
     * @param _tags Array of tags for the post
     * @param _isPremium Whether the post is premium content
     */
    function createBlogPost(
        string memory _title,
        string memory _content,
        string[] memory _tags,
        bool _isPremium
    ) external isRegisteredAuthor {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_content).length > 0, "Content cannot be empty");
        require(_tags.length <= 10, "Maximum 10 tags allowed");
        
        uint256 postId = totalPosts;
        
        blogPosts[postId] = BlogPost({
            id: postId,
            author: msg.sender,
            title: _title,
            content: _content,
            tags: _tags,
            timestamp: block.timestamp,
            likes: 0,
            views: 0,
            isPublished: true, // Auto-publish for simplicity
            isPremium: _isPremium,
            tipAmount: 0
        });
        
        authorPosts[msg.sender].push(postId);
        authors[msg.sender].totalPosts++;
        totalPosts++;
        
        emit PostCreated(postId, msg.sender, _title);
        emit PostPublished(postId, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Interact with blog posts (like, view, comment)
     * @param _postId ID of the post to interact with
     * @param _action Type of interaction (1=like, 2=view, 3=comment)
     * @param _commentContent Content of comment (only for comment action)
     */
    function interactWithPost(
        uint256 _postId,
        uint8 _action,
        string memory _commentContent
    ) external postExists(_postId) isRegisteredAuthor {
        BlogPost storage post = blogPosts[_postId];
        require(post.isPublished, "Post is not published");
        
        if (_action == 1) { // Like post
            require(!postLikes[_postId][msg.sender], "Already liked this post");
            postLikes[_postId][msg.sender] = true;
            post.likes++;
            authors[post.author].totalLikes++;
            emit PostLiked(_postId, msg.sender);
            
        } else if (_action == 2) { // View post
            post.views++;
            emit PostViewed(_postId, msg.sender);
            
        } else if (_action == 3) { // Comment on post
            require(bytes(_commentContent).length > 0, "Comment cannot be empty");
            require(bytes(_commentContent).length <= 1000, "Comment too long");
            
            Comment memory newComment = Comment({
                id: totalComments,
                postId: _postId,
                commenter: msg.sender,
                content: _commentContent,
                timestamp: block.timestamp,
                likes: 0
            });
            
            postComments[_postId].push(newComment);
            totalComments++;
            
            emit CommentAdded(_postId, totalComments - 1, msg.sender);
        } else {
            revert("Invalid action");
        }
    }
    
    /**
     * @dev Core Function 3: Tip authors and manage author profiles
     * @param _postId ID of the post to tip (0 for profile management)
     * @param _username Username for registration (only for profile management)
     * @param _bio Bio for registration (only for profile management)
     * @param _isRegistration Whether this is a registration call
     */
    function tipAuthorOrManageProfile(
        uint256 _postId,
        string memory _username,
        string memory _bio,
        bool _isRegistration
    ) external payable {
        
        if (_isRegistration) {
            // Register author profile
            require(bytes(authors[msg.sender].username).length == 0, "Author already registered");
            require(bytes(_username).length > 0, "Username cannot be empty");
            require(bytes(_username).length <= 50, "Username too long");
            
            authors[msg.sender] = Author({
                authorAddress: msg.sender,
                username: _username,
                bio: _bio,
                totalPosts: 0,
                totalLikes: 0,
                totalTips: 0,
                isVerified: false,
                joinDate: block.timestamp
            });
            
            emit AuthorRegistered(msg.sender, _username);
            
        } else {
            // Tip author
            require(msg.value > 0, "Tip amount must be greater than 0");
            require(_postId < totalPosts, "Post does not exist");
            
            BlogPost storage post = blogPosts[_postId];
            require(post.author != msg.sender, "Cannot tip your own post");
            require(post.isPublished, "Post is not published");
            
            // Calculate platform fee
            uint256 fee = (msg.value * platformFee) / 1000;
            uint256 authorTip = msg.value - fee;
            
            // Update tip amounts
            post.tipAmount += msg.value;
            authors[post.author].totalTips += authorTip;
            
            // Transfer payments
            payable(post.author).transfer(authorTip);
            payable(owner).transfer(fee);
            
            emit TipSent(_postId, msg.sender, post.author, authorTip);
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Get blog post details
     */
    function getBlogPost(uint256 _postId) 
        external 
        view 
        postExists(_postId) 
        returns (BlogPost memory) 
    {
        return blogPosts[_postId];
    }
    
    /**
     * @dev Get author details
     */
    function getAuthor(address _authorAddress) 
        external 
        view 
        returns (Author memory) 
    {
        return authors[_authorAddress];
    }
    
    /**
     * @dev Get posts by author
     */
    function getAuthorPosts(address _author) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return authorPosts[_author];
    }
    
    /**
     * @dev Get comments for a post
     */
    function getPostComments(uint256 _postId) 
        external 
        view 
        postExists(_postId) 
        returns (Comment[] memory) 
    {
        return postComments[_postId];
    }
    
    /**
     * @dev Follow/unfollow an author
     */
    function followAuthor(address _authorToFollow, bool _follow) external isRegisteredAuthor {
        require(_authorToFollow != msg.sender, "Cannot follow yourself");
        require(bytes(authors[_authorToFollow].username).length > 0, "Author not registered");
        
        following[msg.sender][_authorToFollow] = _follow;
        
        if (_follow) {
            emit AuthorFollowed(msg.sender, _authorToFollow);
        }
    }
    
    /**
     * @dev Get recent posts (last 10)
     */
    function getRecentPosts() external view returns (uint256[] memory) {
        uint256 count = totalPosts > 10 ? 10 : totalPosts;
        uint256[] memory recentPosts = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            recentPosts[i] = totalPosts - 1 - i;
        }
        
        return recentPosts;
    }
    
    /**
     * @dev Verify author (only owner)
     */
    function verifyAuthor(address _author) external onlyOwner {
        require(bytes(authors[_author].username).length > 0, "Author not registered");
        authors[_author].isVerified = true;
    }
    
    /**
     * @dev Update platform fee (only owner)
     */
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 50, "Platform fee cannot exceed 5%");
        platformFee = _newFee;
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformStats() 
        external 
        view 
        returns (uint256 posts, uint256 comments, uint256 totalAuthors) 
    {
        return (totalPosts, totalComments, totalPosts); // Simplified count
    }
}
